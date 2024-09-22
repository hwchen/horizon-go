//TODO skip whitespace
module sgf;

import std::collections::list;
import std::core::array;
import std::core::mem::allocator;
import std::core::mem;
import std::io;

def Props = List(<Prop>);
def Nodes = List(<Node*>);

// Tree of games. One tree can hold multiple games.
struct GameTree {
	Node* root;
}

struct Node {
	Props props;
	Nodes children;
}

struct Prop {
	String label;
	String data;
}

enum Player {
	BLACK,
	WHITE,
}

fn GameTree! parse_sgf(String src, Allocator alloc) {
	Parser p = { .src = src };
	Node* root = mem::new(Node);;
	root.children.new_init();

	// stack tracks scopes; A node is put on here if it's the parent of a new scope
	Nodes stack;
	stack.temp_init();
	Node* parent = root;
	@pool() { // TODO can I use defer/free the stack?
		while(true) {
			if (p.match("(")) {
				stack.push(parent);
			}
			if (p.match(")")) {
				stack.pop()!;
				Node*! last = stack.last();
				if (catch last) break;
				parent = last;
			}
			p.match(";");

			Props props;
			props.new_init();
			while (p.peek()! != ';' && p.peek()! != '(' && p.peek()! != ')') {
				Prop prop = p.prop(alloc)!;
				props.push(prop);
			}

			Node* node = mem::new(Node, { .props = props });
			parent.children.push(node);
			parent = node;
			//io::printfn("stack_len: %d, Rest: %s", stack.len(), p.src[p.curr..]);
		}
	};
	return { .root = root };
}

struct Parser {
	usz curr;
	char[] src;
}

fn bool Parser.match(&p, String s) {
	if (p.curr + s.len > p.src.len) {
		return false;
	}
	if (s == p.src[p.curr:s.len]) {
		p.curr += 1;
		return true;
	} else {
		return false;
	}

}
fn void! Parser.expect(&p, String s) {
	if (s == p.src[p.curr:s.len]) {
		p.curr += s.len;
	} else {
		return ParseError.UNEXPECTED?;
	}
}
fn char! Parser.peek(&p) {
	return p.src[p.curr];
}
fn Prop! Parser.prop(&p, Allocator alloc) {
	usz! split_idx = array::index_of(p.src[p.curr..], '[');
	usz! end_idx = array::index_of(p.src[p.curr..], ']');
	if (catch split_idx) {
		return ParseError.EXPECTED_PROP?;
	}
	if (catch end_idx) {
		return ParseError.EXPECTED_PROP?;
	}
	Prop prop = {
		.label = ((String)p.src[p.curr: split_idx]).copy(),
		.data = ((String)p.src[p.curr + split_idx + 1:end_idx - split_idx - 1]).copy(),
	};
	//io::printfn("Prop: %s, %s", prop.label, prop.data);
	p.curr += end_idx + 1;
	return prop;
}

fault ParseError {
	UNEXPECTED,
	EXPECTED_PROP,
}

fn void! test_no_variation() @test {
	String input = "(;FF[4]GM[1]SZ[19];B[aa];W[bb];B[cc];W[dd];B[ad];W[bd])";
	GameTree gt = parse_sgf(input, allocator::heap())!;
	// root has only one child
	assert(gt.root.children.len() == 1);
	// root node has only one child
	Node* node = gt.root.children[0];
	assert(node.children.len() == 1);
	// next five nodes have only one child
	for (int i; i < 5; i += 1) {
		node = node.children[0];
		assert(node.children.len() == 1);
	}
	// last node has no child
	node = node.children[0];
	assert(node.children.len() == 0);
	// TODO refactor, there's got to be a cleaner way to test
}

fn void! test_one_variation() @test {
	String input = "(;FF[4]GM[1]SZ[19];B[aa];W[bb](;B[cc];W[dd];B[ad];W[bd])(;B[hh];W[hg]))";
	GameTree gt = parse_sgf(input, allocator::heap())!;
}
