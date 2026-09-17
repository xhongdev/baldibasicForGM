if (!is_undefined(loading)) {
    if (bb_school_loading_tick(loading,delta_time/1000000)) {
        if (global.bb_selftest) {
            bb_test_loading_complete(loading);
            if (global.test_loading_mode=="story") room_goto(rm_title);
            else {
                show_debug_message("BB_TEST_RESULT: "+string(global.test_total)+" checks, "+string(global.test_failed)+" failures");
                game_end();
            }
        }
        loading=undefined;
    }
    exit;
}
if (global.bb_selftest) {
    test_frames += 1;
    if (test_frames == 2) global.G.inv = [1, 4, 9];
    if (test_frames == 3) {
        global.G.state = "yctp";
        global.G.yctp_q = 1; global.G.yctp_end = false;
        global.G.yctp_a = 3; global.G.yctp_b = 2; global.G.yctp_op = "+";
        global.G.yctp_input = "5";
    }
    if (test_frames == 4) {
        global.G.state = "play";
        bb_debug_open();
    }
    if (test_frames >= 5) {
        room_goto(rm_title);
    }
} else {
    bb_game_update(delta_time / 1000000);
}
