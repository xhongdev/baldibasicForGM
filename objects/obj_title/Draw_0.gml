bb_ui_begin();
draw_clear(c_white);
var _selected=(menu_selection>=0 && menu_selection<array_length(menu_buttons))?menu_buttons[menu_selection].key:"";
switch (menu_page) {
    case "warning":
        bb_warning_draw();
        break;
    case "title":
        draw_sprite_stretched(spr_title,0,0,0,640,480);
        bb_menu_button_draw("start",_selected=="start");
        bb_menu_button_draw("main_menu",_selected=="main_menu");
        bb_menu_button_draw("exit",_selected=="exit");
        break;
    case "modes":
        var _story=global.P.menu.text.story,_endless=global.P.menu.text.endless;
        bb_yctp_text(_story.value,_story,false,false,_selected=="story");
        var _endless_value=_endless.value+"\nHigh Score: "+string(global.high_books)+" Notebooks";
        var _endless_fit=bb_menu_endless_text_node(_endless_value);
        bb_yctp_text(_endless_value,_endless_fit,false,true,_selected=="endless");
        bb_menu_button_draw("endless",_selected=="endless");
        bb_menu_button_draw("story",_selected=="story");
        bb_menu_button_draw("play_back",_selected=="play_back");
        break;
    case "menu":
        bb_menu_button_draw("how",_selected=="how");
        bb_menu_button_draw("options",_selected=="options");
        bb_menu_button_draw("credits",_selected=="credits");
        bb_menu_button_draw("menu_back",_selected=="menu_back");
        break;
    case "options":
        bb_menu_button_draw("turn",_selected=="turn");
        bb_menu_button_draw("controls",_selected=="controls");
        bb_menu_button_draw("rumble",_selected=="rumble");
        if (global.rumble_enabled) bb_menu_asset_draw(global.P.menu.checks.asset,global.P.menu.checks.rumble);
        bb_menu_button_draw("analog",_selected=="analog");
        if (global.analog_movement) bb_menu_asset_draw(global.P.menu.checks.asset,global.P.menu.checks.analog);
        bb_menu_slider_draw();
        bb_menu_button_draw("options_back",_selected=="options_back");
        break;
    case "story_info":
        var _story_bg=global.P.menu.backgrounds.story;
        bb_menu_asset_draw(_story_bg.asset,_story_bg.rect);
        bb_menu_button_draw("story_back",_selected=="story_back");
        break;
    case "credits":
        draw_clear(c_black);
        var _credits_bg=global.P.menu.backgrounds.credits;
        bb_menu_asset_draw(_credits_bg.asset,_credits_bg.rect);
        bb_menu_button_draw("credits_back",_selected=="credits_back");
        break;
    case "controls":
        var _controls=global.P.menu.text.controls;
        bb_yctp_text(_controls.value,_controls,false,false);
        bb_menu_button_draw("controls_back",_selected=="controls_back");
        break;
}
draw_set_halign(fa_left);draw_set_valign(fa_top);draw_set_color(c_white);draw_set_alpha(1);
if (global.bb_selftest) surface_save(application_surface,"bb_menu_"+menu_page+".png");
