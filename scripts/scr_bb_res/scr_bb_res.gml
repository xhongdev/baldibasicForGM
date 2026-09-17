function bb_base_w() {
    if (variable_global_exists("base_w")) {
        return global.base_w;
    }
    return 640;
}

function bb_base_h() {
    if (variable_global_exists("base_h")) {
        return global.base_h;
    }
    return 480;
}

function bb_res_init() {
    global.base_w = 640;
    global.base_h = 480;
    global.res_scale = 1;
    global.res_x = 0;
    global.res_y = 0;
    global.res_w = 640;
    global.res_h = 480;
    global.res_win_w = -1;
    global.res_win_h = -1;
    global.res_fs = window_get_fullscreen();

    application_surface_draw_enable(false);
    gpu_set_texfilter(false);
    surface_resize(application_surface, global.base_w, global.base_h);
    display_set_gui_size(global.base_w, global.base_h);

    if (!window_get_fullscreen()) {
        var _dw = display_get_width();
        var _dh = display_get_height();
        var _s = min(_dw / global.base_w, _dh / global.base_h) * 0.9;
        if (_s < 1) {
            _s = min(_dw / global.base_w, _dh / global.base_h);
        }
        window_set_size(max(global.base_w, round(global.base_w * _s)), max(global.base_h, round(global.base_h * _s)));
        window_center();
    }
    bb_res_apply();
}

function bb_res_apply() {
    var _bw = bb_base_w();
    var _bh = bb_base_h();
    var _ww = max(1, window_get_width());
    var _hh = max(1, window_get_height());
    var _s = min(_ww / _bw, _hh / _bh);
    global.res_scale = _s;
    global.res_w = _bw * _s;
    global.res_h = _bh * _s;
    global.res_x = (_ww - global.res_w) * 0.5;
    global.res_y = (_hh - global.res_h) * 0.5;
    global.res_win_w = _ww;
    global.res_win_h = _hh;
    global.res_fs = window_get_fullscreen();

    if (surface_exists(application_surface)) {
        if (surface_get_width(application_surface) != _bw || surface_get_height(application_surface) != _bh) {
            surface_resize(application_surface, _bw, _bh);
        }
    }
    display_set_gui_size(_bw, _bh);
    display_set_gui_maximise(_s, _s, global.res_x, global.res_y);
}

function bb_res_tick() {
    if (keyboard_check_pressed(vk_f11) || (keyboard_check(vk_alt) && keyboard_check_pressed(vk_enter))) {
        window_set_fullscreen(!window_get_fullscreen());
        bb_res_apply();
        return;
    }
    if (window_get_width() != global.res_win_w || window_get_height() != global.res_win_h || window_get_fullscreen() != global.res_fs) {
        bb_res_apply();
    }
}

function bb_res_post_draw() {
    gpu_set_ztestenable(false);
    gpu_set_zwriteenable(false);
    gpu_set_blendenable(false);
    gpu_set_cullmode(cull_noculling);
    draw_clear(c_black);
    if (surface_exists(application_surface)) {
        gpu_set_texfilter(false);
        gpu_set_tex_mip_enable(mip_off);
        draw_surface_stretched(application_surface, global.res_x, global.res_y, global.res_w, global.res_h);
    }
    gpu_set_blendenable(true);
}
