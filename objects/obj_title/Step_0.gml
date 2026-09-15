if (global.bb_selftest) {
    var _pages=["title","modes","options","controls"];
    if (test_title_frames>=array_length(_pages)) {
        bb_game_init();
        bb_test_assert(ds_map_size(global.floors)==682 && array_length(global.G.doors)==23
            && !bb_blocked_world(global.G.px,global.G.pz,global.G.radius,true),"school restarts safely after returning to title");
        bb_game_cleanup();
        show_debug_message("BB_TEST_RESULT: "+string(global.test_total)+" checks, "+string(global.test_failed)+" failures");
        game_end();
    } else {
        menu_page=_pages[test_title_frames++];menu_buttons=bb_menu_layout(menu_page);menu_selection=0;
    }
    exit;
}
var _mx=device_mouse_x_to_gui(0),_my=device_mouse_y_to_gui(0);
var _clicked=mouse_check_button_pressed(mb_left),_activate=false;
if (_mx!=menu_mouse_x || _my!=menu_mouse_y || _clicked) {
    for (var _i=0; _i<array_length(menu_buttons); _i++) {
        if (bb_hit_btn(menu_buttons[_i])) { menu_selection=_i;_activate=_clicked; }
    }
}
menu_mouse_x=_mx;menu_mouse_y=_my;
var _count=array_length(menu_buttons);
if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(vk_right)) menu_selection=(menu_selection+1) mod _count;
if (keyboard_check_pressed(vk_up) || keyboard_check_pressed(vk_left)) menu_selection=(menu_selection+_count-1) mod _count;
if ((keyboard_check_pressed(vk_enter) && !keyboard_check(vk_alt)) || keyboard_check_pressed(vk_space)) _activate=true;
var _action=_activate?menu_buttons[menu_selection].action:"";
if (keyboard_check_pressed(vk_escape) && menu_page!="title") _action=(menu_page=="modes" || menu_page=="menu")?"title":"menu";
switch (_action) {
    case "story": bb_start_mode("story");break;
    case "endless": bb_start_mode("endless");break;
    case "quit": game_end();break;
    case "sensitivity_down": global.mouse_sensitivity=max(.1,global.mouse_sensitivity-.1);bb_settings_save();break;
    case "sensitivity_up": global.mouse_sensitivity=min(3,global.mouse_sensitivity+.1);bb_settings_save();break;
    case "volume_down": global.master_volume=max(0,global.master_volume-.1);audio_master_gain(global.master_volume);bb_settings_save();break;
    case "volume_up": global.master_volume=min(1,global.master_volume+.1);audio_master_gain(global.master_volume);bb_settings_save();break;
    case "fullscreen": window_set_fullscreen(!window_get_fullscreen());bb_res_apply();break;
    default:
        if (_action!="") { menu_page=_action;menu_selection=0;menu_buttons=bb_menu_layout(menu_page); }
        break;
}
