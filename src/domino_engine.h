#ifndef DOMINO_ENGINE_H
#define DOMINO_ENGINE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <vector>

namespace godot {

class DominoEngine : public RefCounted {
	GDCLASS(DominoEngine, RefCounted)

	struct Tile {
		int a;
		int b;
	};

	std::vector<Tile> ph, ah, bone, board;
	int left_end = -1, right_end = -1;
	int turn = 0, passes = 0, winner = 0, round_points = 0;
	int pscore = 0, ascore = 0;
	bool over = false;

	int ends_mask(const Tile &t) const;
	bool has_move(const std::vector<Tile> &h) const;
	void place(Tile t, int side);
	static int pips(const std::vector<Tile> &h);
	void finish_empty(int who);
	void finish_blocked();

protected:
	static void _bind_methods();

public:
	void new_game();
	void reset_scores();
	Array get_player_hand() const;
	Array get_board() const;
	int get_ai_count() const { return (int)ah.size(); }
	int get_bone_count() const { return (int)bone.size(); }
	int get_turn() const { return turn; }
	bool is_over() const { return over; }
	int get_winner() const { return winner; }
	int get_round_points() const { return round_points; }
	int get_player_score() const { return pscore; }
	int get_ai_score() const { return ascore; }
	int get_left_end() const { return left_end; }
	int get_right_end() const { return right_end; }
	int can_play(int index) const;
	bool player_has_move() const;
	bool play_player(int index, int side);
	Vector2i player_draw();
	bool player_pass();
	Dictionary ai_turn();
};

} // namespace godot

#endif
