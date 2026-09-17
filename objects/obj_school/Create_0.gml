test_frames = 0;
loading = undefined;
if (global.school_loading_pending) {
    global.school_loading_pending = false;
    loading = bb_school_loading_begin();
} else {
    bb_game_init();
    if (global.bb_selftest) bb_run_selftests();
}
