function bb_presentation_init() {
    global.P = json_parse(bb_read_text("presentation.json"));
    global.PS = {};
    var _files = {};
    var _keys = variable_struct_get_names(global.P.textures);
    for (var _i = 0; _i < array_length(_keys); _i++) {
        var _key = _keys[_i];
        var _path = global.P.textures[$ _key].file;
        if (!variable_struct_exists(_files, _path)) _files[$ _path] = bb_load_png(_path, 0, 0);
        global.PS[$ _key] = _files[$ _path];
    }
    global.S = bb_audio_assets();
}

function bb_ui_begin() {
    shader_reset();
    gpu_set_ztestenable(false);
    gpu_set_zwriteenable(false);
    gpu_set_cullmode(cull_noculling);
    gpu_set_alphatestenable(false);
    gpu_set_texrepeat(false);
    gpu_set_texfilter(false);
    gpu_set_blendenable(true);
    gpu_set_blendmode(bm_normal);
    draw_set_alpha(1);
    draw_set_color(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

function bb_ui_texture(_key, _r) {
    var _spr = global.PS[$ _key];
    draw_sprite_ext(_spr, 0, _r[0], _r[1], _r[2] / sprite_get_width(_spr), _r[3] / sprite_get_height(_spr), 0, c_white, 1);
}

function bb_ui_fit_sprite(_spr, _r) {
    var _s = min(_r[2] / sprite_get_width(_spr), _r[3] / sprite_get_height(_spr));
    var _x = _r[0] + (_r[2] - sprite_get_width(_spr)*_s)*0.5;
    var _y = _r[1] + (_r[3] - sprite_get_height(_spr)*_s)*0.5;
    draw_sprite_ext(_spr, 0, _x + sprite_get_xoffset(_spr)*_s, _y + sprite_get_yoffset(_spr)*_s, _s, _s, 0, c_white, 1);
}

function bb_ui_text(_text, _r, _font, _colour) {
    draw_set_font(_font);
    draw_set_color(_colour);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    var _height = string_height_ext(_text, -1, _r[2]);
    draw_text_ext(_r[0] + _r[2]*0.5, _r[1] + max(0, (_r[3]-_height)*0.5), _text, -1, _r[2]);
    draw_set_halign(fa_left);
    draw_set_color(c_white);
}

function bb_present_hud(_g, _gw, _gh) {
    bb_ui_begin();
    draw_set_font(global.fnt_small);
    draw_text(8, 6, string(_g.notebooks) + "/7 Notebooks");
    var _bx = (_gw - 150)*0.5;
    draw_set_color(make_colour_rgb(180, 0, 0));
    draw_rectangle(_bx, 8, _bx + 150, 20, false);
    draw_set_color(make_colour_rgb(40, 200, 40));
    draw_rectangle(_bx, 8, _bx + 150*clamp(_g.stamina/_g.stamina_max, 0, 1), 20, false);
    if (_g.stamina < 0) bb_ui_text("YOU NEED REST!", [_bx-20, 22, 190, 24], global.fnt_small, c_red);
    var _hud = global.P.hud;
    var _sel = _hud.itemSelect.rect;
    var _sx = _sel[0] + _g.inv_sel * 40;
    draw_set_color(make_colour_rgb(200, 32, 32));
    draw_rectangle(_sx, _sel[1], _sx + _sel[2], _sel[1] + _sel[3], false);
    bb_ui_texture("slots", _hud.ItemSlots.rect);
    for (var _i = 0; _i < 3; _i++) {
        if (_g.inv[_i] > 0) bb_ui_fit_sprite(bb_item_spr(_g.inv[_i]), _hud[$ "slot" + string(_i)].rect);
    }
    bb_ui_text(bb_item_name(_g.inv[_g.inv_sel]), _hud.itemText.rect, global.fnt_small, c_white);
}

function bb_yctp_layout_init() {
    global.yctp_pad = [];
    var _keys = ["7", "8", "9", "4", "5", "6", "1", "2", "3", "C", "0", "-", "OK"];
    var _values = [7, 8, 9, 4, 5, 6, 1, 2, 3, -2, 0, -1, -3];
    for (var _i = 0; _i < array_length(_keys); _i++) {
        var _node = global.P.yctp[$ "Button (" + _keys[_i] + ")"];
        var _r = _node.rect;
        array_push(global.yctp_pad, {x1:_r[0], y1:_r[1], x2:_r[0]+_r[2], y2:_r[1]+_r[3],
            v:_values[_i], rect:_r, texture:_node.texture});
    }
}

function bb_present_yctp() {
    var _g = global.G, _ui = global.P.yctp;
    bb_ui_begin();
    bb_ui_texture(_ui.YCTP.texture, _ui.YCTP.rect);
    var _q = _ui.question.rect;
    if (_g.yctp_end) {
        bb_ui_text(_g.yctp_msg, _q, global.fnt_ui, make_colour_rgb(16, 48, 16));
    } else {
        bb_ui_text("SOLVE MATH Q" + string(_g.yctp_q) + ":", [_q[0], _q[1], _q[2], 38], global.fnt_ui, make_colour_rgb(16, 48, 16));
        if (_g.yctp_corrupt) {
            var _bad = [_g.yctp_bad1, _g.yctp_bad2, _g.yctp_bad3];
            for (var _i = 0; _i < 3; _i++) {
                bb_ui_text(_bad[_i], [_q[0], _q[1]+42+_i*20, _q[2], 34], global.fnt_small, make_colour_rgb(16, 48, 16));
            }
        } else {
            bb_ui_text(string(_g.yctp_a) + _g.yctp_op + string(_g.yctp_b) + "=", [_q[0], _q[1]+52, _q[2], 70], global.fnt_big, make_colour_rgb(16, 48, 16));
        }
        bb_ui_text(_g.yctp_input, _ui.answer.rect, global.fnt_big, c_black);
    }
    for (var _i = 0; _i < 3; _i++) {
        if (_g.yctp_marks[_i] != 0) bb_ui_texture(_g.yctp_marks[_i] > 0 ? "check" : "xmark", _ui[$ "Result" + string(_i+1)].rect);
    }
    if (!_g.spoop_mode) bb_ui_fit_sprite(global.spr_wave[99], _ui.BaldiFeed.rect);
    for (var _i = 0; _i < array_length(global.yctp_pad); _i++) {
        var _key = global.yctp_pad[_i];
        bb_ui_texture(_key.texture, _key.rect);
    }
    bb_ui_begin();
}

function bb_draw_exit_signs() {
    var _g = global.G;
    for (var _i = 0; _i < array_length(global.P.exit_signs); _i++) {
        var _s = global.P.exit_signs[_i];
        var _visible = true;
        if (_s.entrance != "") {
            for (var _e = 0; _e < array_length(_g.exits); _e++) {
                if (_g.exits[_e].name == _s.entrance) _visible = !_g.exits[_e].down;
            }
        }
        if (_visible) bb3d_draw_billboard(global.PS[$ _s.texture], 0, _s.x, _s.y, _s.z, _s.w, _s.h, _g.px, _g.pz, c_white);
    }
}
