if (!is_undefined(loading)) { draw_clear(c_white);exit; }
if (global.bb_selftest && test_frames == 1) bb_test_render();
bb_game_draw();
