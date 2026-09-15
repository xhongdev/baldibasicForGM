if (global.bb_selftest && test_frames == 1) bb_test_presentation_render();
bb_game_draw_gui();
bb_debug_draw();
if (global.bb_selftest && test_frames == 2) screen_save("bb_school_window.png");
if (global.bb_selftest && test_frames == 3) screen_save("bb_yctp_window.png");
if (global.bb_selftest && test_frames == 4) screen_save("bb_cheat_menu.png");
