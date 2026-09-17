function bb_presentation_init() {
    global.P = json_parse(bb_read_text("presentation.json"));
    global.E = json_parse(bb_read_text(global.P.environment_file));
    global.PS = {};
    var _files = {};
    var _keys = variable_struct_get_names(global.P.textures);
    for (var _i = 0; _i < array_length(_keys); _i++) {
        var _key = _keys[_i];
        var _path = global.P.textures[$ _key].file;
        if (!variable_struct_exists(_files, _path)) {
            var _asset=global.P.textures[$ _key];
            var _frames=variable_struct_exists(_asset,"frames")?_asset.frames:1;
            _files[$ _path] = bb_load_png(_path, 0, 0, _frames);
        }
        global.PS[$ _key] = _files[$ _path];
    }
    global.S = bb_audio_assets();
    global.A = json_parse(bb_read_text("audio_manifest.json"));
}

function bb_loading_texture(_time) {
    var _load=global.P.menu.loading,_frames=_load.frames;
    var _phase=max(0,_time) mod _load.duration,_texture=_frames[0].texture;
    for (var _i=1;_i<array_length(_frames);_i++) {
        if (_frames[_i].time>_phase) break;
        _texture=_frames[_i].texture;
    }
    return _texture;
}

function bb_loading_draw(_time) {
    bb_ui_begin();
    var _load=global.P.menu.loading;
    draw_set_color(c_white);draw_rectangle(0,0,640,480,false);
    bb_ui_texture(bb_loading_texture(_time),_load.rect);
    bb_yctp_text(_load.text.value,_load.text,false,false);
}

function bb_ui_begin() {
    shader_reset();
    gpu_set_ztestenable(false);
    gpu_set_zwriteenable(false);
    gpu_set_cullmode(cull_noculling);
    gpu_set_alphatestenable(false);
    gpu_set_texrepeat(false);
    gpu_set_texfilter(false);
    gpu_set_tex_mip_enable(mip_off);
    gpu_set_blendenable(true);
    gpu_set_blendmode(bm_normal);
    draw_set_alpha(1);
    draw_set_color(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

function bb_ui_texture(_key, _r, _frame = 0) {
    var _spr = global.PS[$ _key];
    draw_sprite_ext(_spr, _frame, _r[0], _r[1], _r[2] / sprite_get_width(_spr), _r[3] / sprite_get_height(_spr), 0, c_white, 1);
}

function bb_pause_frame(_time) {
    var _pause=global.P.pause,_phase=max(0,_time) mod _pause.duration,_frame=0;
    for (var _i=1;_i<array_length(_pause.frame_times);_i++) {
        if (_pause.frame_times[_i]>_phase) break;
        _frame=_i;
    }
    return _frame;
}

function bb_pause_draw() {
    bb_ui_begin();
    var _g=global.G,_pause=global.P.pause;
    // The source BG Blocker is transparent; retain the frozen scene behind it.
    bb_yctp_text(_pause.text.value,_pause.text);
    for (var _i=0;_i<array_length(_pause.buttons);_i++) {
        var _button=_pause.buttons[_i];
        bb_ui_texture(_button.texture,_button.rect,_g.pause_hover==_i?bb_pause_frame(_g.pause_time):0);
    }
}

function bb_warning_draw() {
    bb_ui_begin();
    var _warning=global.P.warning;
    bb_ui_texture(_warning.texture,_warning.rect);
}

function bb_menu_asset_draw(_asset,_r,_preserve=false) {
    var _spr=global.PS[$ _asset.texture],_src=_asset.crop;
    var _x=_r[0],_y=_r[1],_w=_r[2],_h=_r[3];
    if (_preserve) {
        var _scale=min(_w/_src[2],_h/_src[3]);
        _x+=(_w-_src[2]*_scale)*.5;_y+=(_h-_src[3]*_scale)*.5;
        _w=_src[2]*_scale;_h=_src[3]*_scale;
    }
    draw_sprite_part_ext(_spr,0,_src[0],_src[1],_src[2],_src[3],
        _x,_y,_w/_src[2],_h/_src[3],c_white,1);
}

function bb_menu_button_draw(_key,_selected) {
    var _node=global.P.menu.buttons[$ _key];
    bb_menu_asset_draw(_selected?_node.selected:_node.normal,_node.rect,_node.preserve);
}

function bb_menu_slider_draw() {
    var _menu=global.P.menu,_slider=_menu.slider,_range=_slider.max-_slider.min;
    var _amount=clamp((global.mouse_sensitivity-_slider.min)/_range,0,1),_bar=_slider.bar;
    draw_set_color(c_red);draw_rectangle(_bar[0],_bar[1],_bar[0]+_bar[2],_bar[1]+_bar[3],false);
    draw_set_color(c_lime);draw_rectangle(_bar[0],_bar[1],lerp(_slider.track[0],_slider.track[1],_amount),_bar[1]+_bar[3],false);
    draw_set_color(c_white);
    var _source=_slider.handle_rect;
    var _handle=[lerp(_slider.track[0],_slider.track[1],_amount)-_source[2]*.5,
        _source[1],_source[2],_source[3]];
    bb_menu_asset_draw(_slider.handle,_handle);
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
    // Unity's active reticle is a small black point at the viewport center.
    if (_g.state == "play" && !_g.pause) {
        draw_set_color(c_black);
        draw_circle(_gw * .5, _gh * .5, 2, false);
        draw_set_color(c_white);
    }
    draw_set_font(global.fnt_small);
    draw_text(8, 6, string(_g.notebooks) + (_g.mode == "story" ? "/7 Notebooks" : " Notebooks"));
    var _bx = (_gw - 150)*0.5;
    draw_set_color(make_colour_rgb(180, 0, 0));
    draw_rectangle(_bx, 8, _bx + 150, 20, false);
    draw_set_color(make_colour_rgb(40, 200, 40));
    draw_rectangle(_bx, 8, _bx + 150*clamp(_g.stamina/_g.stamina_max, 0, 1), 20, false);
    if (_g.stamina < 0) bb_ui_text("YOU NEED REST!", [_bx-20, 22, 190, 24], global.fnt_small, c_red);
    var _hud = global.P.hud;
    bb_ui_solid(global.P.details.hud.item_background);
    var _sel = _hud.itemSelect.rect;
    var _sx = _sel[0] + _g.inv_sel * 40;
    draw_set_color(make_colour_rgb(200, 32, 32));
    draw_rectangle(_sx, _sel[1], _sx + _sel[2], _sel[1] + _sel[3], false);
    for (var _i = 0; _i < 3; _i++) {
        if (_g.inv[_i] > 0) bb_ui_fit_sprite(bb_item_spr(_g.inv[_i]), _hud[$ "slot" + string(_i)].rect);
    }
    bb_ui_texture("slots", _hud.ItemSlots.rect);
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
            v:_values[_i], rect:_r, texture:_node.texture, highlighted:_node.highlighted});
    }
}

function bb_ui_solid(_node) {
    var _r = _node.rect, _c = _node.colour;
    draw_set_color(make_colour_rgb(_c[0]*255, _c[1]*255, _c[2]*255));
    draw_set_alpha(_c[3]);
    draw_rectangle(_r[0], _r[1], _r[0]+_r[2], _r[1]+_r[3], false);
    draw_set_alpha(1); draw_set_color(c_white);
}

function bb_yctp_glyph(_char) {
    var _glyphs = global.P.yctp_font.glyphs, _key = string(ord(_char));
    return variable_struct_exists(_glyphs, _key) ? _glyphs[$ _key] : _glyphs[$ "63"];
}

// Lay out the source bitmap glyphs using the TMP baseline, advances and line height.
function bb_yctp_text_layout(_text, _node, _single = false) {
    var _font = global.P.yctp_font, _r = _node.rect;
    var _scale = _node.font_size / _font.size, _spacing = _node.spacing;
    var _line_step=_font.line_height*_scale
        +(variable_struct_exists(_node,"line_spacing")?_node.line_spacing:0);
    var _x = 0, _y = _font.ascent * _scale, _glyphs = [];
    for (var _i = 1; _i <= string_length(_text); _i++) {
        var _ch = string_char_at(_text, _i);
        if (_ch == "\n") { _x = 0; _y += _line_step; continue; }
        if (!_single && _ch != " " && (_i == 1 || string_char_at(_text, _i-1) == " ")) {
            var _word = 0;
            for (var _j = _i; _j <= string_length(_text); _j++) {
                var _next = string_char_at(_text, _j);
                if (_next == " " || _next == "\n") break;
                _word += bb_yctp_glyph(_next).advance * _scale + _spacing;
            }
            if (_x > 0 && _x + _word > _r[2]) { _x = 0; _y += _line_step; }
        }
        var _glyph = bb_yctp_glyph(_ch), _advance = _glyph.advance * _scale + _spacing;
        if (!_single && _x > 0 && _x + _advance > _r[2]) { _x = 0; _y += _line_step; }
        if (_ch != " ") array_push(_glyphs, {x:_r[0]+_x+_glyph.bearing[0]*_scale,
            y:_r[1]+_y-_glyph.bearing[1]*_scale, src:_glyph.src, scale:_scale, baseline:_y,
            origin:_r[0]+_x, right:_r[0]+_x+_advance});
        _x += _advance;
    }
    // TMP single-line input scrolls to keep the latest digits inside its viewport.
    if (_single && _x > _r[2]) {
        for (var _i = 0; _i < array_length(_glyphs); _i++) {
            _glyphs[_i].x -= _x - _r[2];
            _glyphs[_i].origin -= _x - _r[2];
            _glyphs[_i].right -= _x - _r[2];
        }
    }
    var _halign = _node.alignment & 255;
    if (!_single && _halign != 1) {
        for (var _i = 0; _i < array_length(_glyphs);) {
            var _end = _i, _baseline = _glyphs[_i].baseline;
            while (_end+1 < array_length(_glyphs) && _glyphs[_end+1].baseline == _baseline) _end += 1;
            var _width = _glyphs[_end].right - _r[0];
            var _offset = (_r[2] - _width) * (_halign == 2 ? 0.5 : 1);
            for (var _j = _i; _j <= _end; _j++) {
                _glyphs[_j].x += _offset;_glyphs[_j].origin += _offset;_glyphs[_j].right += _offset;
            }
            _i = _end + 1;
        }
    }
    if ((_node.alignment & 512) != 0) {
        var _height = _y + 7 * _scale;
        var _offset=(_r[3] - _height) * 0.5;
        for (var _i = 0; _i < array_length(_glyphs); _i++) {
            _glyphs[_i].y += _offset;_glyphs[_i].baseline += _offset;
        }
    }
    return _glyphs;
}

function bb_yctp_text_fit_node(_text, _node, _rect) {
    var _fit=variable_clone(_node);
    _fit.rect=_rect;
    for (var _attempt=0;_attempt<8;_attempt++) {
        var _glyphs=bb_yctp_text_layout(_text,_fit),_top=1000000,_bottom=-1000000;
        for (var _i=0;_i<array_length(_glyphs);_i++) {
            var _glyph=_glyphs[_i];
            _top=min(_top,_glyph.y);
            _bottom=max(_bottom,_glyph.y+_glyph.src[3]*_glyph.scale);
        }
        if (array_length(_glyphs)==0 || (_top>=_rect[1]+1 && _bottom<=_rect[1]+_rect[3]-1)) break;
        var _height=max(1,_bottom-_top);
        _fit.font_size=max(12,_fit.font_size*clamp((_rect[3]-2)/_height*.99,.75,.98));
    }
    return _fit;
}

function bb_menu_endless_text_node(_text) {
    var _menu=global.P.menu,_source=_menu.text.endless,_story=_menu.text.story.rect;
    var _back_top=_menu.buttons.play_back.hit[1];
    var _top=_story[1]+_story[3]+4;
    var _rect=[_source.rect[0],_top,_source.rect[2],max(1,_back_top-_top-4)];
    return bb_yctp_text_fit_node(_text,_source,_rect);
}

function bb_yctp_underline_layout(_glyphs,_node) {
    var _result=[],_font=global.P.yctp_font,_scale=_node.font_size/_font.size;
    var _offset=-_font.underline_offset*_scale;
    var _thickness=_font.underline_thickness*_scale;
    for (var _i=0;_i<array_length(_glyphs);) {
        var _end=_i,_baseline=_glyphs[_i].baseline;
        while (_end+1<array_length(_glyphs) && _glyphs[_end+1].baseline==_baseline) _end+=1;
        var _y=_node.rect[1]+_baseline+_offset;
        array_push(_result,[_glyphs[_i].origin,_y,_glyphs[_end].right,_y+_thickness]);
        _i=_end+1;
    }
    return _result;
}

function bb_yctp_text(_text, _node, _single = false, _clip = true, _underline = false) {
    var _glyphs = bb_yctp_text_layout(_text, _node, _single), _layout_rect = _node.rect;
    var _r = _clip ? _layout_rect : [-10000, -10000, 20000, 20000];
    var _spr = global.PS[$ global.P.yctp_font.texture];
    var _c = _node.colour, _colour = make_colour_rgb(_c[0]*255, _c[1]*255, _c[2]*255);
    for (var _i = 0; _i < array_length(_glyphs); _i++) {
        var _g = _glyphs[_i], _s = _g.scale, _src = _g.src;
        var _x1 = max(_g.x, _r[0]), _y1 = max(_g.y, _r[1]);
        var _x2 = min(_g.x+_src[2]*_s, _r[0]+_r[2]), _y2 = min(_g.y+_src[3]*_s, _r[1]+_r[3]);
        if (_x2 <= _x1 || _y2 <= _y1) continue;
        draw_sprite_part_ext(_spr, 0, _src[0]+(_x1-_g.x)/_s, _src[1]+(_y1-_g.y)/_s,
            (_x2-_x1)/_s, (_y2-_y1)/_s, _x1, _y1, _s, _s, _colour, _c[3]);
    }
    if (_underline && array_length(_glyphs)>0) {
        draw_set_color(_colour);draw_set_alpha(_c[3]);
        var _lines=bb_yctp_underline_layout(_glyphs,_node);
        for (var _i=0;_i<array_length(_lines);_i++) {
            var _line=_lines[_i];
            var _x1=max(_line[0],_r[0]),_y1=max(_line[1],_r[1]);
            var _x2=min(_line[2],_r[0]+_r[2]),_y2=min(_line[3],_r[1]+_r[3]);
            if (_x2>_x1 && _y2>_y1) draw_rectangle(_x1,_y1,_x2,_y2,false);
        }
        draw_set_alpha(1);draw_set_color(c_white);
    }
}

function bb_yctp_face_update(_dt) {
    var _g = global.G;
    if (!_g.yctp_face_visible) return;
    var _state = _g.yctp_face_state;
    if (_state != "frown") {
        var _handle = _g.voices.math.handle;
        _state = (!_g.spoop_mode && _handle != -1 && audio_is_playing(_handle) && !audio_is_paused(_handle)) ? "talk" : "idle";
    }
    if (_state != _g.yctp_face_state) _g.yctp_face_time = 0;
    _g.yctp_face_state = _state;
    _g.yctp_face_time += _dt;
}

function bb_yctp_face_texture() {
    var _g = global.G, _anim = global.P.yctp_face[$ _g.yctp_face_state];
    var _time = _g.yctp_face_time * _anim.speed;
    if (_anim.loop) _time = _time mod _anim.duration;
    var _key = _anim.frames[0].texture;
    for (var _i = 1; _i < array_length(_anim.frames); _i++) {
        if (_anim.frames[_i].time > _time) break;
        _key = _anim.frames[_i].texture;
    }
    return _key;
}

function bb_present_yctp(_mx = undefined, _my = undefined) {
    var _g = global.G, _ui = global.P.yctp;
    if (is_undefined(_mx)) _mx=device_mouse_x_to_gui(0);
    if (is_undefined(_my)) _my=device_mouse_y_to_gui(0);
    // Share the click hit areas and source SpriteSwap state, including C, - and OK.
    var _hover=bb_yctp_pad_at(_mx,_my);
    bb_ui_begin();
    bb_ui_solid(_ui.BG);
    bb_ui_solid(_ui.Image);
    bb_ui_solid(_ui.TextBG);
    bb_ui_solid(_ui.answerBackground);
    for (var _i = 0; _i < 3; _i++) {
        if (_g.yctp_marks[_i] != 0) bb_ui_texture(_g.yctp_marks[_i] > 0 ? "check" : "xmark", _ui[$ "Result" + string(_i+1)].rect);
    }
    if (_g.yctp_face_visible) bb_ui_texture(bb_yctp_face_texture(), _ui.BaldiFeed.rect);
    // The shell masks its inset screens, results and video feed.
    bb_ui_texture(_ui.YCTP.texture, _ui.YCTP.rect);
    if (_g.yctp_end) {
        bb_yctp_text(_g.yctp_msg, _ui.question);
    } else {
        var _header = "SOLVE MATH Q" + string(_g.yctp_q) + ": \n";
        if (_g.yctp_corrupt) {
            bb_yctp_text(_header + _g.yctp_bad1, _ui.question);
            bb_yctp_text(_header + _g.yctp_bad2, _ui.question2);
            bb_yctp_text(_header + _g.yctp_bad3, _ui.question3);
        } else {
            bb_yctp_text(_header + " \n" + string(_g.yctp_a) + _g.yctp_op + string(_g.yctp_b) + "=", _ui.question);
        }
        bb_yctp_text(_g.yctp_input, _ui.answer, true);
    }
    for (var _i = 0; _i < array_length(global.yctp_pad); _i++) {
        var _key = global.yctp_pad[_i];
        bb_ui_texture(!is_undefined(_hover) && _hover==_key.v ? _key.highlighted : _key.texture, _key.rect);
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
