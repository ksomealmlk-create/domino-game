#include "domino_engine.h"

#include <algorithm>
#include <random>

using namespace godot;

static std::mt19937 &rng() {
	static std::mt19937 g{ std::random_device{}() };
	return g;
}

void DominoEngine::_bind_methods() {
	ClassDB::bind_method(D_METHOD("new_game"), &DominoEngine::new_game);
	ClassDB::bind_method(D_METHOD("reset_scores"), &DominoEngine::reset_scores);
	ClassDB::bind_method(D_METHOD("get_player_hand"), &DominoEngine::get_player_hand);
	ClassDB::bind_method(D_METHOD("get_board"), &DominoEngine::get_board);
	ClassDB::bind_method(D_METHOD("get_ai_count"), &DominoEngine::get_ai_count);
	ClassDB::bind_method(D_METHOD("get_bone_count"), &DominoEngine::get_bone_count);
	ClassDB::bind_method(D_METHOD("get_turn"), &DominoEngine::get_turn);
	ClassDB::bind_method(D_METHOD("is_over"), &DominoEngine::is_over);
	ClassDB::bind_method(D_METHOD("get_winner"), &DominoEngine::get_winner);
	ClassDB::bind_method(D_METHOD("get_round_points"), &DominoEngine::get_round_points);
	ClassDB::bind_method(D_METHOD("get_player_score"), &DominoEngine::get_player_score);
	ClassDB::bind_method(D_METHOD("get_ai_score"), &DominoEngine::get_ai_score);
	ClassDB::bind_method(D_METHOD("get_left_end"), &DominoEngine::get_left_end);
	ClassDB::bind_method(D_METHOD("get_right_end"), &DominoEngine::get_right_end);
	ClassDB::bind_method(D_METHOD("can_play", "index"), &DominoEngine::can_play);
	ClassDB::bind_method(D_METHOD("player_has_move"), &DominoEngine::player_has_move);
	ClassDB::bind_method(D_METHOD("play_player", "index", "side"), &DominoEngine::play_player);
	ClassDB::bind_method(D_METHOD("player_draw"), &DominoEngine::player_draw);
	ClassDB::bind_method(D_METHOD("player_pass"), &DominoEngine::player_pass);
	ClassDB::bind_method(D_METHOD("ai_turn"), &DominoEngine::ai_turn);
}

int DominoEngine::ends_mask(const Tile &t) const {
	if (board.empty()) return 1;
	int m = 0;
	if (t.a == left_end || t.b == left_end) m |= 1;
	if (t.a == right_end || t.b == right_end) m |= 2;
	return m;
}

bool DominoEngine::has_move(const std::vector<Tile> &h) const {
	for (const Tile &t : h) {
		if (ends_mask(t) > 0) return true;
	}
	return false;
}

void DominoEngine::place(Tile t, int side) {
	if (board.empty()) {
		board.push_back(t);
		left_end = t.a;
		right_end = t.b;
		return;
	}
	if (side == 0) {
		Tile n = (t.b == left_end) ? Tile{ t.a, t.b } : Tile{ t.b, t.a };
		board.insert(board.begin(), n);
		left_end = n.a;
	} else {
		Tile n = (t.a == right_end) ? Tile{ t.a, t.b } : Tile{ t.b, t.a };
		board.push_back(n);
		right_end = n.b;
	}
}

int DominoEngine::pips(const std::vector<Tile> &h) {
	int s = 0;
	for (const Tile &t : h) s += t.a + t.b;
	return s;
}

void DominoEngine::finish_empty(int who) {
	over = true;
	winner = who;
	if (who == 1) {
		round_points = pips(ah);
		pscore += round_points;
	} else {
		round_points = pips(ph);
		ascore += round_points;
	}
}

void DominoEngine::finish_blocked() {
	over = true;
	int p = pips(ph), a = pips(ah);
	if (p < a) {
		winner = 1;
		round_points = a - p;
		pscore += round_points;
	} else if (a < p) {
		winner = 2;
		round_points = p - a;
		ascore += round_points;
	} else {
		winner = 3;
		round_points = 0;
	}
}

void DominoEngine::new_game() {
	std::vector<Tile> all;
	for (int i = 0; i <= 6; i++)
		for (int j = i; j <= 6; j++) all.push_back(Tile{ i, j });
	std::shuffle(all.begin(), all.end(), rng());
	ph.assign(all.begin(), all.begin() + 7);
	ah.assign(all.begin() + 7, all.begin() + 14);
	bone.assign(all.begin() + 14, all.end());
	board.clear();
	left_end = right_end = -1;
	passes = 0;
	over = false;
	winner = 0;
	round_points = 0;
	auto key = [](const Tile &t) { return t.a == t.b ? 50 + t.a : t.a + t.b; };
	int mp = -1, ma = -1;
	for (const Tile &t : ph) mp = std::max(mp, key(t));
	for (const Tile &t : ah) ma = std::max(ma, key(t));
	turn = (mp >= ma) ? 0 : 1;
}

void DominoEngine::reset_scores() {
	pscore = 0;
	ascore = 0;
}

Array DominoEngine::get_player_hand() const {
	Array r;
	for (const Tile &t : ph) r.push_back(Vector2i(t.a, t.b));
	return r;
}

Array DominoEngine::get_board() const {
	Array r;
	for (const Tile &t : board) r.push_back(Vector2i(t.a, t.b));
	return r;
}

int DominoEngine::can_play(int index) const {
	if (index < 0 || index >= (int)ph.size()) return 0;
	return ends_mask(ph[index]);
}

bool DominoEngine::player_has_move() const {
	return has_move(ph);
}

bool DominoEngine::play_player(int index, int side) {
	if (over || turn != 0) return false;
	if (index < 0 || index >= (int)ph.size()) return false;
	int m = ends_mask(ph[index]);
	if (!board.empty()) {
		int need = (side == 0) ? 1 : 2;
		if (!(m & need)) return false;
	}
	place(ph[index], side);
	ph.erase(ph.begin() + index);
	passes = 0;
	if (ph.empty()) {
		finish_empty(1);
	} else {
		turn = 1;
	}
	return true;
}

Vector2i DominoEngine::player_draw() {
	if (over || turn != 0 || bone.empty() || has_move(ph)) return Vector2i(-1, -1);
	Tile t = bone.back();
	bone.pop_back();
	ph.push_back(t);
	return Vector2i(t.a, t.b);
}

bool DominoEngine::player_pass() {
	if (over || turn != 0 || has_move(ph) || !bone.empty()) return false;
	passes++;
	if (passes >= 2) {
		finish_blocked();
	} else {
		turn = 1;
	}
	return true;
}

Dictionary DominoEngine::ai_turn() {
	Dictionary d;
	d["action"] = String("none");
	d["drawn"] = 0;
	if (over || turn != 1) return d;

	int drawn = 0;
	while (!has_move(ah) && !bone.empty()) {
		ah.push_back(bone.back());
		bone.pop_back();
		drawn++;
	}
	d["drawn"] = drawn;

	int bi = -1, bs = 0, best = -1;
	for (size_t i = 0; i < ah.size(); i++) {
		const Tile &t = ah[i];
		for (int s = 0; s < 2; s++) {
			bool ok;
			if (board.empty()) ok = (s == 0);
			else if (s == 0) ok = (t.a == left_end || t.b == left_end);
			else ok = (t.a == right_end || t.b == right_end);
			if (!ok) continue;
			int sc = t.a + t.b + (t.a == t.b ? 3 : 0) + (int)(rng()() % 3);
			if (sc > best) {
				best = sc;
				bi = (int)i;
				bs = s;
			}
		}
	}

	if (bi >= 0) {
		Tile t = ah[bi];
		place(t, bs);
		ah.erase(ah.begin() + bi);
		passes = 0;
		d["action"] = String("play");
		d["tile"] = Vector2i(t.a, t.b);
		d["side"] = bs;
		if (ah.empty()) finish_empty(2);
		else turn = 0;
	} else {
		passes++;
		d["action"] = String("pass");
		if (passes >= 2) finish_blocked();
		else turn = 0;
	}
	return d;
}
