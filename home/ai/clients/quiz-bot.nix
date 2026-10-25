{
  config,
  lib,
  pkgs,
  base,
  ...
}:
let
  cfg = config.programs.quiz-bot;

  py = pkgs.python3.withPackages (ps: [
    ps.pytesseract
    ps.pillow
  ]);
  omniroute = base.appOf "omniroute";

  script = pkgs.writeText "quiz-bot.py" ''
    import argparse
    import base64
    import hashlib
    import http.client
    import io
    import json
    import os
    import queue
    import random
    import re
    import socket
    import struct
    import subprocess
    import sys
    import threading
    import time
    import unicodedata
    from collections import defaultdict
    from concurrent.futures import ThreadPoolExecutor
    from urllib.parse import urlparse

    import pytesseract
    from PIL import Image

    BASE = urlparse(os.environ["OMNIROUTE_URL"])
    CHAT_PATH = BASE.path.rstrip("/") + "/v1/chat/completions"
    MODEL = os.environ["QUIZ_MODEL"]
    FALLBACK_MODEL = os.environ.get("QUIZ_FALLBACK_MODEL")
    EFFORT = os.environ.get("QUIZ_EFFORT")
    MAX_TOKENS = int(os.environ["QUIZ_MAX_TOKENS"])
    QUESTION_SECONDS = float(os.environ["QUIZ_QUESTION_SECONDS"])
    MARGIN_SECONDS = float(os.environ["QUIZ_MARGIN_SECONDS"])
    GRACE_SECONDS = float(os.environ["QUIZ_GRACE_SECONDS"])
    DETECT_LAG_SECONDS = float(os.environ["QUIZ_DETECT_LAG_SECONDS"])
    LLM_CUTOFF_SECONDS = float(os.environ["QUIZ_LLM_CUTOFF_SECONDS"])
    NEXT_SAFE_SECONDS = float(os.environ["QUIZ_NEXT_SAFE_SECONDS"])
    HEDGE_SECONDS = float(os.environ["QUIZ_HEDGE_SECONDS"])
    MAX_ATTEMPTS = int(os.environ["QUIZ_MAX_ATTEMPTS"])
    PARALLEL = int(os.environ["QUIZ_PARALLEL"])
    TEXT_HEDGE = os.environ["QUIZ_TEXT_HEDGE"] == "1"
    RAW_SCREENSHOT = os.environ["QUIZ_RAW_SCREENSHOT"] == "1"
    IMAGE_WIDTH = int(os.environ["QUIZ_IMAGE_WIDTH"])
    JPEG_QUALITY = int(os.environ["QUIZ_JPEG_QUALITY"])
    COLOR_MODE = os.environ["QUIZ_COLOR"]

    CONTENT_REGION = (0.20, 0.60)
    TITLE_REGION = (0.20, 0.235)
    DIALOG_REGION = (0.30, 0.95)
    NEXT_BOX = (0.806, 0.915, 0.966, 0.963)
    NEXT_ACTIVE_MAX = int(os.environ.get("NEXT_ACTIVE_MAX", "120"))
    NEXT_CENTER = (0.886, 0.938)
    SUBMIT_CENTER = (0.799, 0.146)
    CONFIRM_WORDS = {"xacnhan", "dongy", "nopbai", "nop", "co"}
    OPTION_COUNT = 4
    MIN_CONF = 10
    LINE_GAP = 0.012
    MAX_BAD_OCR = 2

    PROMPT = (
        "Screenshot of a Vietnamese multiple-choice quiz question with four options. "
        "Topics: Vietnam Youth Union, youth policy, Vietnamese politics and history. "
        "Exactly one option is correct. Reply with only the number of the correct "
        "option, counting from the top: 1, 2, 3 or 4. No explanation."
    )

    TEXT_PROMPT = (
        "Vietnamese multiple-choice quiz, text from OCR so it may contain typos and "
        "wrong diacritics. Topics: Vietnam Youth Union, youth policy, Vietnamese "
        "politics and history. Exactly one option is correct. Reply with only the "
        "number of the correct option: 1, 2, 3 or 4. No explanation."
    )

    ANSWERED = set()
    EXTENDED = set()
    SEEN = {}
    HISTORY = []
    KEY_CACHE = []

    if COLOR_MODE == "always":
        COLOR = True
    elif COLOR_MODE == "never":
        COLOR = False
    else:
        COLOR = sys.stdout.isatty() and "NO_COLOR" not in os.environ

    STYLES = {
        "bold": "1",
        "gray": "90",
        "red": "31",
        "green": "32",
        "yellow": "33",
        "magenta": "35",
        "cyan": "36",
    }

    TONES = {
        None: (),
        "ok": ("green",),
        "warn": ("yellow",),
        "err": ("red",),
        "dim": ("gray",),
        "step": ("cyan",),
        "head": ("bold", "magenta"),
    }

    STATUS_STYLE = {
        "answered": ("green",),
        "guessed": ("yellow",),
        "expired": ("red",),
        "skipped": ("red",),
        "dry-run": ("cyan",),
    }


    class Expired(Exception):
        pass


    class Deadline:
        def __init__(self, end):
            self.end = end

        def left(self):
            return self.end - time.time()

        def check(self):
            if self.left() <= 0:
                raise Expired()


    class Job:
        def __init__(self):
            self.conns = []
            self.cancelled = threading.Event()

        def cancel(self):
            self.cancelled.set()
            for conn in list(self.conns):
                abort_connection(conn)


    def paint(text, *styles):
        if not COLOR or not styles:
            return text
        codes = ";".join(STYLES[s] for s in styles)
        return f"\033[{codes}m{text}\033[0m"


    def log(msg, tone=None):
        now = time.time()
        stamp = time.strftime("%H:%M:%S", time.localtime(now)) + f".{int(now * 1000) % 1000:03d}"
        print(paint(stamp, "gray"), paint(msg, *TONES[tone]), flush=True)


    def fresh_end():
        return time.time() + QUESTION_SECONDS - MARGIN_SECONDS - DETECT_LAG_SECONDS


    def end_from_next(state):
        return state["t_next"] + QUESTION_SECONDS - MARGIN_SECONDS


    def api_key():
        if not KEY_CACHE:
            with open(os.environ["OMNIROUTE_API_KEY_FILE"]) as f:
                KEY_CACHE.append(f.read().strip())
        return KEY_CACHE[0]


    def adb(*args, deadline=None):
        timeout = max(deadline.left(), 0.1) if deadline else 10
        try:
            return subprocess.run(
                ["adb", *args], capture_output=True, check=True, timeout=timeout
            ).stdout
        except subprocess.TimeoutExpired as e:
            if deadline:
                raise Expired() from e
            raise


    def screenshot(deadline=None):
        if RAW_SCREENSHOT:
            raw = adb("exec-out", "screencap", deadline=deadline)
            if len(raw) > 16:
                w, h = struct.unpack("<II", raw[:8])
                for head in (16, 12):
                    if len(raw) == head + w * h * 4:
                        img = Image.frombuffer("RGBA", (w, h), raw[head:], "raw", "RGBA", 0, 1)
                        return img.convert("RGB")
        png = adb("exec-out", "screencap", "-p", deadline=deadline)
        return Image.open(io.BytesIO(png))


    def tap(x, y, deadline=None):
        x += random.randint(-8, 8)
        y += random.randint(-8, 8)
        adb("shell", "input", "tap", str(x), str(y), deadline=deadline)


    def tap_ratio(img, ratio, deadline=None):
        w, h = img.size
        tap(int(w * ratio[0]), int(h * ratio[1]), deadline)


    def crop_region(img, region):
        w, h = img.size
        return img.crop((0, int(h * region[0]), w, int(h * region[1])))


    def center(b):
        return (b["x1"] + b["x2"]) // 2, (b["y1"] + b["y2"]) // 2


    def normalize(s):
        s = unicodedata.normalize("NFKD", s.lower().replace("đ", "d"))
        return re.sub(r"[^a-z0-9]", "", s)


    def fingerprint(img):
        area = crop_region(img, TITLE_REGION).convert("L")
        area = area.point(lambda p: 255 if p < 128 else 0)
        return hashlib.sha1(area.tobytes()).hexdigest()[:8]


    def ocr_lines(img, deadline=None, region=CONTENT_REGION, psm=4):
        top = int(img.height * region[0])
        timeout = max(deadline.left(), 0.1) if deadline else 15
        try:
            data = pytesseract.image_to_data(
                crop_region(img, region),
                lang="vie",
                config=f"--oem 1 --psm {psm}",
                output_type=pytesseract.Output.DICT,
                timeout=timeout,
            )
        except RuntimeError as e:
            if deadline and "timeout" in str(e).lower():
                raise Expired() from e
            raise

        groups = defaultdict(list)
        for i, word in enumerate(data["text"]):
            if word.strip() and float(data["conf"][i]) > MIN_CONF:
                key = (data["block_num"][i], data["par_num"][i], data["line_num"][i])
                groups[key].append(i)

        lines = []
        for idxs in groups.values():
            lines.append({
                "text": " ".join(data["text"][i] for i in idxs),
                "x1": min(data["left"][i] for i in idxs),
                "y1": top + min(data["top"][i] for i in idxs),
                "x2": max(data["left"][i] + data["width"][i] for i in idxs),
                "y2": top + max(data["top"][i] + data["height"][i] for i in idxs),
            })
        return sorted(lines, key=lambda line: line["y1"])


    def ocr_blocks(img, deadline=None, psm=4):
        max_gap = LINE_GAP * img.height
        blocks = []
        for line in ocr_lines(img, deadline, CONTENT_REGION, psm):
            prev = blocks[-1] if blocks else None
            if prev and line["y1"] - prev["y2"] < max_gap:
                prev["text"] += " " + line["text"]
                prev["x1"] = min(prev["x1"], line["x1"])
                prev["x2"] = max(prev["x2"], line["x2"])
                prev["y2"] = max(prev["y2"], line["y2"])
            else:
                blocks.append(dict(line))
        return blocks


    def read_screen(img, deadline):
        t = time.time()
        want = OPTION_COUNT + 1
        with ThreadPoolExecutor(max_workers=2) as ex:
            f4 = ex.submit(ocr_blocks, img, deadline, 4)
            f6 = ex.submit(ocr_blocks, img, deadline, 6)
            b4, b6 = f4.result(), f6.result()
        blocks = b6 if len(b4) != want and len(b6) == want else b4
        log(f"  ocr {time.time() - t:.1f}s, {len(blocks)} blocks", "dim")
        return blocks


    def split_blocks(blocks):
        # The last four blocks are the options, anything above is the question.
        if len(blocks) >= OPTION_COUNT + 1:
            question = " ".join(b["text"] for b in blocks[:-OPTION_COUNT])
            return question, blocks[-OPTION_COUNT:]
        question = blocks[0]["text"] if blocks else ""
        return question, blocks[1:]


    def identify(img, question):
        # The OCR often misreads the question number, so the label is just the
        # order in which the bot met each distinct question.
        fp = fingerprint(img)
        if fp not in SEEN:
            SEEN[fp] = len(SEEN) + 1
        return {"fp": fp, "label": f"Q{SEEN[fp]}", "text": question}


    def image_content(img):
        area = crop_region(img, CONTENT_REGION).convert("RGB")
        height = round(area.height * IMAGE_WIDTH / area.width)
        area = area.resize((IMAGE_WIDTH, height), Image.LANCZOS)
        buf = io.BytesIO()
        area.save(buf, "JPEG", quality=JPEG_QUALITY)
        url = "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()
        return [
            {"type": "text", "text": PROMPT},
            {"type": "image_url", "image_url": {"url": url}},
        ]


    def text_content(question, options):
        lines = [question] + [f"{i}. {b['text']}" for i, b in enumerate(options, 1)]
        return [{"type": "text", "text": TEXT_PROMPT + "\n\n" + "\n".join(lines)}]


    def smart_guess(options):
        for i, b in enumerate(options, 1):
            n = normalize(b["text"])
            if "deudung" in n or "tatca" in n:
                return i
        return max(range(len(options)), key=lambda i: len(options[i]["text"])) + 1


    def abort_connection(conn):
        try:
            if conn.sock:
                conn.sock.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        conn.close()


    def chat(body, deadline, job):
        deadline.check()
        conn_cls = (
            http.client.HTTPSConnection
            if BASE.scheme == "https"
            else http.client.HTTPConnection
        )
        conn = conn_cls(BASE.hostname, BASE.port, timeout=max(deadline.left(), 0.1))
        job.conns.append(conn)
        timer = threading.Timer(deadline.left(), abort_connection, args=(conn,))
        timer.start()
        try:
            conn.request(
                "POST",
                CHAT_PATH,
                json.dumps(body),
                {
                    "Content-Type": "application/json",
                    "Authorization": "Bearer " + api_key(),
                },
            )
            resp = conn.getresponse()
            data = resp.read()
        except Exception:
            if job.cancelled.is_set() or deadline.left() <= 0.2:
                raise Expired()
            raise
        finally:
            timer.cancel()
            conn.close()
        if resp.status != 200:
            raise RuntimeError(f"http {resp.status}: {data[:200]!r}")
        parsed = json.loads(data)
        choice = parsed["choices"][0]
        return (
            choice["message"].get("content"),
            choice.get("finish_reason"),
            parsed.get("usage"),
        )


    def ask_once(model, content, deadline, tag, job):
        body = {
            "model": model,
            "temperature": 0,
            "max_tokens": MAX_TOKENS,
            "messages": [{"role": "user", "content": content}],
        }
        if EFFORT:
            body["reasoning_effort"] = EFFORT

        t = time.time()
        text, finish, usage = chat(body, deadline, job)
        m = re.search(r"\b([1-4])\b", text or "")
        if not m:
            raise ValueError(
                f"unexpected reply {text!r} finish_reason={finish} usage={usage}"
            )
        log(f"  llm[{tag}] {time.time() - t:.1f}s -> {m.group(1)}", "step")
        return int(m.group(1))


    def ask(img, blocks_f, job, deadline):
        image = image_content(img)
        models = [MODEL, FALLBACK_MODEL or MODEL]
        results = queue.Queue()
        state = {"launched": 0, "running": 0}

        def pick_content(n):
            # Later requests use the OCR text when it is ready: it is much
            # lighter than an image and the first request already covers the
            # case where the OCR is bad.
            if TEXT_HEDGE and n >= PARALLEL and blocks_f.done() and not blocks_f.exception():
                question, options = split_blocks(blocks_f.result())
                if len(options) == OPTION_COUNT:
                    return "text", text_content(question, options)
            return "image", image

        def launch():
            n = state["launched"]
            model = models[n % len(models)]
            kind, content = pick_content(n)
            tag = f"{n + 1}:{kind}:{model}"
            state["launched"] += 1
            state["running"] += 1

            def run():
                try:
                    results.put((True, ask_once(model, content, deadline, tag, job)))
                except Exception as e:
                    results.put((False, e))

            threading.Thread(target=run, daemon=True).start()

        for _ in range(min(PARALLEL, MAX_ATTEMPTS)):
            launch()
        next_hedge = time.time() + HEDGE_SECONDS

        while True:
            if job.cancelled.is_set():
                raise Expired()
            left = deadline.left()
            if left <= 0:
                raise Expired()
            wait = min(left, 0.25)
            if state["launched"] < MAX_ATTEMPTS:
                wait = min(wait, max(next_hedge - time.time(), 0.05))
            try:
                ok, val = results.get(timeout=wait)
            except queue.Empty:
                if (
                    state["launched"] < MAX_ATTEMPTS
                    and time.time() >= next_hedge
                    and deadline.left() > 1.0
                ):
                    log(f"  llm no answer after {HEDGE_SECONDS:.0f}s, sending another request", "warn")
                    launch()
                    next_hedge = time.time() + HEDGE_SECONDS
                continue

            state["running"] -= 1
            if ok:
                return val
            if isinstance(val, Expired):
                if state["running"] == 0:
                    raise Expired()
                continue

            log(f"  llm attempt failed: {val}", "warn")
            if state["launched"] < MAX_ATTEMPTS and deadline.left() > 1.0:
                launch()
                next_hedge = time.time() + HEDGE_SECONDS
            elif state["running"] == 0:
                raise RuntimeError(val)


    def next_redness(img):
        w, h = img.size
        area = (
            int(w * NEXT_BOX[0]),
            int(h * NEXT_BOX[1]),
            int(w * NEXT_BOX[2]),
            int(h * NEXT_BOX[3]),
        )
        return img.convert("RGB").crop(area).getchannel("R").getextrema()[0]


    def next_enabled(img):
        return next_redness(img) < NEXT_ACTIVE_MAX


    def add_history(q, chosen, status, secs):
        HISTORY.append({
            "label": q["label"],
            "fp": q["fp"],
            "text": q["text"],
            "chosen": chosen,
            "status": status,
            "secs": secs,
        })


    def log_question(q, options, choice, guessed, secs, last):
        tone = "yellow" if guessed else "green"
        head = f"[{q['label']}] #{q['fp']} {secs:.1f}s" + (" (last)" if last else "")
        log(head, "head")
        log("  " + paint(q["text"], "bold"))
        for i, b in enumerate(options, 1):
            if i == choice:
                tag = "  (guess)" if guessed else ""
                log(paint(f"  > {i}. {b['text']}{tag}", "bold", tone))
            else:
                log(paint(f"    {i}. {b['text']}", "gray"))


    def print_summary():
        if not HISTORY:
            return
        log("==== SUMMARY ====", "head")
        counts = defaultdict(int)
        for h in HISTORY:
            counts[h["status"]] += 1
            status = paint(f"{h['status']:<8}", *STATUS_STYLE.get(h["status"], ()))
            log(f"{h['label']:<4} {status} {h['secs']:>5.1f}s  {h['text']}")
            log(paint(f"       -> {h['chosen']}", "gray"))
        parts = [
            paint(f"{n} {name}", *STATUS_STYLE.get(name, ()))
            for name, n in counts.items()
        ]
        log("total: " + ", ".join(parts))


    def await_change(old_fp, timeout):
        end = time.time() + timeout
        while time.time() < end:
            try:
                img = screenshot(Deadline(end))
            except Expired:
                break
            if fingerprint(img) != old_fp:
                return img
        return None


    def submit():
        tap_ratio(screenshot(), SUBMIT_CENTER)
        time.sleep(1.2)
        lines = ocr_lines(screenshot(), None, DIALOG_REGION)
        log(f"after submit: {[line['text'] for line in lines]}", "dim")
        for line in reversed(lines):
            if normalize(line["text"]) in CONFIRM_WORDS:
                x, y = center(line)
                tap(x, y)
                log(f"confirmed: {line['text']}", "ok")
                return
        log("no confirm button found, check the screen", "err")


    def advance(img, last, deadline, state):
        if last:
            submit()
            return "done"
        state["t_next"] = time.time()
        log("  pressing next", "dim")
        tap_ratio(img, NEXT_CENTER, deadline)
        return "next"


    def solve_one(n, deadline, state, dry):
        deadline.check()
        t0 = time.time()
        img = state.pop("img", None)
        if img is None:
            img = screenshot(deadline)
        last = not next_enabled(img)

        # The LLM stops a bit before the question deadline so that there is
        # always time left to tap an answer, real or guessed.
        llm_deadline = Deadline(deadline.end - LLM_CUTOFF_SECONDS)

        pool = ThreadPoolExecutor(max_workers=2)
        job = Job()
        guessed = False
        try:
            blocks_f = pool.submit(read_screen, img, deadline)
            answer_f = pool.submit(ask, img, blocks_f, job, llm_deadline)
            blocks = blocks_f.result()
            question, options = split_blocks(blocks)

            if len(blocks) < 2 or (
                len(options) != OPTION_COUNT
                and state["bad_ocr"] < MAX_BAD_OCR
                and deadline.left() > 5
            ):
                state["bad_ocr"] += 1
                log(f"[{n}] screen not ready ({len(blocks)} blocks), retrying", "warn")
                time.sleep(0.3)
                return "retry"
            state["bad_ocr"] = 0

            q = identify(img, question)
            state.update(q=q, last=last)

            if q["fp"] in ANSWERED:
                state["repeat"] += 1
                if state["repeat"] > 3:
                    log(f"[{n}] {q['label']} #{q['fp']} keeps reappearing, giving up", "err")
                    return "done"
                log(f"[{n}] {q['label']} #{q['fp']} already answered, pressing next again", "warn")
                return advance(img, last, deadline, state)
            state["repeat"] = 0

            try:
                choice = answer_f.result()
            except Exception as e:
                if len(options) == OPTION_COUNT:
                    choice = smart_guess(options)
                else:
                    choice = random.randint(1, OPTION_COUNT)
                guessed = True
                reason = "too slow" if isinstance(e, Expired) else f"error: {e}"
                log(f"[{n}] {q['label']} llm {reason}, guessing {choice}", "warn")
        finally:
            job.cancel()
            pool.shutdown(wait=False, cancel_futures=True)

        target = None
        if choice and len(options) == OPTION_COUNT:
            target = options[choice - 1]
        elif choice:
            log(f"[{n}] expected {OPTION_COUNT} options, OCR found {len(options)}, not tapping", "err")

        secs = time.time() - t0
        log_question(q, options, choice, guessed, secs, last)
        chosen = target["text"] if target else "-"
        if dry:
            add_history(q, chosen, "dry-run", secs)
            return "done"

        # The hard limit for tapping is the app's own timeout.
        app_end = deadline.end + MARGIN_SECONDS
        tail = Deadline(app_end)

        if target:
            tail.check()
            x, y = center(target)
            tap(x, y, tail)
            ANSWERED.add(q["fp"])
            add_history(q, chosen, "guessed" if guessed else "answered", secs)
            log(f"  tapped option {choice}, app time left ~{app_end - time.time():.1f}s", "dim")
        else:
            add_history(q, chosen, "skipped", secs)

        # A late Next press would skip the following question.
        if not last and app_end - time.time() < NEXT_SAFE_SECONDS:
            log(f"[{n}] {q['label']} too close to app timeout, letting the app advance", "warn")
            return "wait"

        tail.check()
        return advance(img, last, tail, state)


    def on_expired(n, state):
        q = state["q"]
        if q is None:
            log(f"[{n}] aborted before the question was read, restarting clock", "warn")
            return "retry", fresh_end()

        try:
            cur = fingerprint(screenshot(Deadline(time.time() + 6)))
        except Expired:
            log(f"[{n}] could not verify the screen after timeout, restarting clock", "warn")
            return "retry", fresh_end()

        if cur != q["fp"]:
            log(f"[{n}] {q['label']} #{q['fp']} ran out of time, app moved on", "err")
            if q["fp"] not in ANSWERED:
                add_history(q, "-", "expired", 0.0)
            state["q"] = None
            return "changed", fresh_end()

        if q["fp"] not in EXTENDED:
            EXTENDED.add(q["fp"])
            log(
                f"[{n}] {q['label']} #{q['fp']} is still on screen, "
                f"bot clock was ahead, extending {GRACE_SECONDS:.0f}s",
                "warn",
            )
            return "extend", time.time() + GRACE_SECONDS

        log(f"[{n}] {q['label']} #{q['fp']} still unchanged after extension, forcing next", "err")
        return "stuck", fresh_end()


    def main():
        ap = argparse.ArgumentParser()
        ap.add_argument("--max", type=int, default=100)
        ap.add_argument("--dry-run", action="store_true")
        ap.add_argument("--probe", action="store_true")
        args = ap.parse_args()

        if args.probe:
            img = screenshot()
            v = next_redness(img)
            log(f"next button min red = {v}, enabled = {v < NEXT_ACTIVE_MAX}")
            log(f"fingerprint = {fingerprint(img)}")
            for b in read_screen(img, Deadline(time.time() + 30)):
                log(f"  {b['text']}")
            return

        state = {"q": None, "last": False, "repeat": 0, "bad_ocr": 0, "t_next": 0.0, "img": None}
        end = fresh_end()

        try:
            for n in range(1, args.max + 1):
                try:
                    status = solve_one(n, Deadline(end), state, args.dry_run)
                except Expired:
                    status, end = on_expired(n, state)

                if status == "done":
                    break
                if status in ("retry", "extend"):
                    continue
                if status == "changed":
                    end = fresh_end()
                    continue
                if status == "wait":
                    if state["q"]:
                        state["img"] = await_change(
                            state["q"]["fp"],
                            MARGIN_SECONDS + NEXT_SAFE_SECONDS + 3.0,
                        )
                    state["q"] = None
                    end = fresh_end()
                    continue
                if status == "next":
                    if state["q"]:
                        state["img"] = await_change(state["q"]["fp"], 3.0)
                    state["q"] = None
                    end = end_from_next(state)
                    continue
                if status == "stuck":
                    ref = state["q"]["fp"]
                    moved = await_change(ref, 3.0)
                    if moved is not None:
                        state["img"] = moved
                        end = fresh_end()
                    else:
                        if state["last"]:
                            submit()
                            break
                        state["t_next"] = time.time()
                        tap_ratio(screenshot(), NEXT_CENTER)
                        state["img"] = await_change(ref, 3.0)
                        end = end_from_next(state)
                    state["q"] = None
        except KeyboardInterrupt:
            log("interrupted", "warn")
        finally:
            print_summary()


    main()
  '';

  effortLine = lib.optionalString (
    cfg.reasoningEffort != null
  ) "export QUIZ_EFFORT=\"\${QUIZ_EFFORT:-${cfg.reasoningEffort}}\"";

  fallbackLine = lib.optionalString (
    cfg.fallbackModel != null
  ) "export QUIZ_FALLBACK_MODEL=\"\${QUIZ_FALLBACK_MODEL:-${cfg.fallbackModel}}\"";

  flag = b: if b then "1" else "0";

  package = pkgs.writeShellApplication {
    name = "quiz-bot";
    runtimeInputs = [
      pkgs.android-tools
      (pkgs.tesseract.override {
        enableLanguages = [
          "vie"
          "eng"
        ];
      })
    ];
    text = ''
      export OMP_THREAD_LIMIT=1
      export OMNIROUTE_URL="''${OMNIROUTE_URL:-${cfg.omnirouteUrl}}"
      export QUIZ_MODEL="''${QUIZ_MODEL:-${cfg.model}}"
      export QUIZ_MAX_TOKENS="''${QUIZ_MAX_TOKENS:-${toString cfg.maxTokens}}"
      export QUIZ_QUESTION_SECONDS="''${QUIZ_QUESTION_SECONDS:-${toString cfg.questionSeconds}}"
      export QUIZ_MARGIN_SECONDS="''${QUIZ_MARGIN_SECONDS:-${toString cfg.marginSeconds}}"
      export QUIZ_GRACE_SECONDS="''${QUIZ_GRACE_SECONDS:-${toString cfg.graceSeconds}}"
      export QUIZ_DETECT_LAG_SECONDS="''${QUIZ_DETECT_LAG_SECONDS:-${toString cfg.detectLagSeconds}}"
      export QUIZ_LLM_CUTOFF_SECONDS="''${QUIZ_LLM_CUTOFF_SECONDS:-${toString cfg.llmCutoffSeconds}}"
      export QUIZ_NEXT_SAFE_SECONDS="''${QUIZ_NEXT_SAFE_SECONDS:-${toString cfg.nextSafeSeconds}}"
      export QUIZ_HEDGE_SECONDS="''${QUIZ_HEDGE_SECONDS:-${toString cfg.hedgeSeconds}}"
      export QUIZ_MAX_ATTEMPTS="''${QUIZ_MAX_ATTEMPTS:-${toString cfg.maxAttempts}}"
      export QUIZ_PARALLEL="''${QUIZ_PARALLEL:-${toString cfg.parallel}}"
      export QUIZ_TEXT_HEDGE="''${QUIZ_TEXT_HEDGE:-${flag cfg.textHedge}}"
      export QUIZ_RAW_SCREENSHOT="''${QUIZ_RAW_SCREENSHOT:-${flag cfg.rawScreenshot}}"
      export QUIZ_IMAGE_WIDTH="''${QUIZ_IMAGE_WIDTH:-${toString cfg.imageWidth}}"
      export QUIZ_JPEG_QUALITY="''${QUIZ_JPEG_QUALITY:-${toString cfg.jpegQuality}}"
      export QUIZ_COLOR="''${QUIZ_COLOR:-${cfg.color}}"
      export OMNIROUTE_API_KEY_FILE="''${OMNIROUTE_API_KEY_FILE:-${
        config.sops.secrets.${cfg.secretName}.path
      }}"
      ${effortLine}
      ${fallbackLine}
      exec ${py}/bin/python ${script} "$@"
    '';
  };
in
{
  options.programs.quiz-bot = {
    enable = lib.mkEnableOption "quiz-bot, an ADB quiz solver backed by OmniRoute";

    secretName = lib.mkOption {
      type = lib.types.str;
      default = "api-keys/omniroute/quiz-bot";
      description = "sops secret holding the OmniRoute API key for this bot.";
    };

    omnirouteUrl = lib.mkOption {
      type = lib.types.str;
      default = omniroute.urlBase;
      defaultText = lib.literalExpression "(base.appOf \"omniroute\").urlBase";
      description = "Base URL of the OmniRoute instance.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "gemini/gemini-3.6-flash";
      description = "OmniRoute model or combo used to answer questions. Must accept image input.";
    };

    fallbackModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "gemini/gemini-3.8-flash-lite";
      description = ''
        Optional second model. Requests alternate between the primary and the
        fallback model, so parallel and hedged requests take different routes.
        Must accept image input. When null, the primary model is used for all.
      '';
    };

    reasoningEffort = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "low";
      description = "Optional reasoning_effort sent to OmniRoute; null omits the field.";
    };

    maxTokens = lib.mkOption {
      type = lib.types.int;
      default = 512;
      description = "Completion token cap. Reasoning tokens count toward it, so too small a value yields empty replies.";
    };

    questionSeconds = lib.mkOption {
      type = lib.types.int;
      default = 20;
      description = "Time the app gives for each question.";
    };

    marginSeconds = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Safety margin subtracted from the per-question time before aborting.";
    };

    graceSeconds = lib.mkOption {
      type = lib.types.int;
      default = 6;
      description = "Extra time granted once when the bot times out but the question is still on screen.";
    };

    detectLagSeconds = lib.mkOption {
      type = lib.types.float;
      default = 1.0;
      description = ''
        Estimated delay between the app starting a question and the bot noticing it.
        Subtracted from the budget whenever the bot clock cannot be anchored to its own Next tap.
      '';
    };

    llmCutoffSeconds = lib.mkOption {
      type = lib.types.float;
      default = 1.0;
      description = ''
        The LLM calls are aborted this many seconds before the bot's question
        deadline, leaving time to tap a guess instead of leaving the question
        blank. A tap takes roughly 0.2s.
      '';
    };

    nextSafeSeconds = lib.mkOption {
      type = lib.types.float;
      default = 1.5;
      description = ''
        If less than this many seconds remain before the app's own timeout after
        answering, the bot does not press Next and lets the app advance by itself,
        which avoids skipping the following question.
      '';
    };

    parallel = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = ''
        Number of LLM requests launched immediately for each question. The first
        valid answer wins and the others are cancelled. Higher values cost more
        quota and can trigger rate limits.
      '';
    };

    hedgeSeconds = lib.mkOption {
      type = lib.types.float;
      default = 3.0;
      description = ''
        If no answer arrived after this many seconds, another request is sent
        (up to maxAttempts). A failed attempt triggers the next one immediately.
      '';
    };

    maxAttempts = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Maximum number of LLM requests (parallel and hedged) per question.";
    };

    textHedge = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Send the OCR text instead of the image in hedged requests when the OCR
        has already finished. The first requests always use the image.
      '';
    };

    imageWidth = lib.mkOption {
      type = lib.types.int;
      default = 720;
      description = "Width in pixels the question image is scaled to before upload.";
    };

    jpegQuality = lib.mkOption {
      type = lib.types.int;
      default = 75;
      description = "JPEG quality of the uploaded question image.";
    };

    rawScreenshot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Capture raw RGBA frames instead of PNG, which skips compression on the
        device. Falls back to PNG when the output cannot be parsed. Disable it
        when adb runs over a slow link such as wifi.
      '';
    };

    color = lib.mkOption {
      type = lib.types.enum [
        "auto"
        "always"
        "never"
      ];
      default = "auto";
      description = "ANSI colors in the log. auto enables them on a TTY unless NO_COLOR is set.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = package;
      readOnly = true;
      description = "The resulting quiz-bot package.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.${cfg.secretName} = { };
    home.packages = [ cfg.package ];
  };
}
