{
  programs.quiz-bot = {
    enable = true;
    reasoningEffort = "low";
    model = "gemini/gemini-3.1-flash-lite";
    fallbackModel = "gemini/gemini-3.1-flash-lite-preview";
    parallel = 1;
    maxAttempts = 2;
    hedgeSeconds = 8.0;
  };

  imports = [
    ./quiz-bot.module.nix
  ];
}
