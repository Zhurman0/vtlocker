// UI concept overview:

// Blocks: logical containers with position and a list of lines (at least).
// Lines: atomic render units tracking current and previous length.
//  - Minimal diff rendering, only changed segments printed.
// Modifiers: composable behavior layers (movement, input, focus, animation).
// Event system: epoll-driven input, modifiers intercept events.
