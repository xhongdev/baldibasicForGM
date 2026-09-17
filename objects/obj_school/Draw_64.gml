if (!is_undefined(loading)) {
    bb_loading_draw(loading.time);
    loading.drawn=true;
    if (global.bb_selftest) {
        loading.presented+=1;
        var _texture=bb_loading_texture(loading.time);
        if (loading.last_texture!="" && loading.last_texture!=_texture) loading.frame_changes+=1;
        loading.last_texture=_texture;
        if (loading.presented==1) screen_save("bb_loading_"+global.game_mode+"_check.png");
    }
    exit;
}
if (global.bb_selftest && test_frames == 1) bb_test_presentation_render();
bb_game_draw_gui();
bb_debug_draw();
if (global.bb_selftest && test_frames == 2) screen_save("bb_school_window.png");
if (global.bb_selftest && test_frames == 3) screen_save("bb_yctp_window.png");
if (global.bb_selftest && test_frames == 4) screen_save("bb_cheat_menu.png");
