module horizon;

import std::core::mem;
import std::io;
import sgf;

fn void! main() {
	String input = "(;FF[4]GM[1]SZ[19];B[aa];W[bb](;B[cc];W[dd];B[ad];W[bd])(;B[hh];W[hg]))";
	io::printn(input);

	DynamicArenaAllocator arena;
	arena.init(1024, allocator::heap());
	defer arena.free();

	GameTree gt = sgf::parse_sgf(input, &arena)!;
}
