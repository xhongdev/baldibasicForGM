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
