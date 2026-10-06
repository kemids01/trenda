// lib/features/home/utils/carousel_loop.dart
// Endless carousels: swiping past the last card lands on the first, and back
// from the first lands on the last.
//
// A PageView with no itemCount is unbounded to the right but still stops at
// page 0, so the carousel opens deep in the middle of the range ([kLoopCycles]
// rounds in) and maps every page onto a real item with [loopIndex]. Nobody
// swipes 500 rounds in either direction, so neither end is ever reached.

/// Rounds of the list on each side of the opening page.
const int kLoopCycles = 500;

/// A single card has nothing to loop to; it stays a plain, bounded page.
bool carouselLoops(int count) => count > 1;

/// The PageView page to open on so that [loopIndex] gives [offset].
int loopInitialPage(int count, [int offset = 0]) =>
    carouselLoops(count) ? count * kLoopCycles + offset : offset;

/// The real item index for a PageView [page]. Safe if the list changed length
/// after the controller was created.
int loopIndex(int page, int count) => count <= 0 ? 0 : page % count;

/// itemCount for the PageView: null (unbounded) when looping.
int? loopItemCount(int count) => carouselLoops(count) ? null : count;
