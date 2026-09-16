if (global.bb_selftest) {
    var _pages=["title","modes","menu","options","story_info","credits","controls"];
    if (test_title_frames>=array_length(_pages)) {
        bb_game_init();
        bb_test_assert(ds_map_size(global.floors)==682 && array_length(global.G.doors)==23
            && !bb_blocked_world(global.G.px,global.G.pz,global.G.radius,true),"school restarts safely after returning to title");
        bb_game_cleanup();
        show_debug_message("BB_TEST_RESULT: "+string(global.test_total)+" checks, "+string(global.test_failed)+" failures");
        game_end();
    } else {
        menu_page=_pages[test_title_frames++];menu_buttons=bb_menu_layout(menu_page);menu_selection=-1;
    }
    exit;
}
var _mx=device_mouse_x_to_gui(0),_my=device_mouse_y_to_gui(0);
var _clicked=mouse_check_button_pressed(mb_left),_activate=false;
if (_mx!=menu_mouse_x || _my!=menu_mouse_y || _clicked) {
    menu_selection=-1;
    for (var _i=0; _i<array_length(menu_buttons); _i++) {
        if (bb_hit_btn(menu_buttons[_i])) { menu_selection=_i;_activate=_clicked; }
    }
}
menu_mouse_x=_mx;menu_mouse_y=_my;
var _count=array_length(menu_buttons);
var _next=keyboard_check_pressed(vk_down),_previous=keyboard_check_pressed(vk_up);
var _right=keyboard_check_pressed(vk_right),_left=keyboard_check_pressed(vk_left);
if (_count>0 && (_next || _previous || _right || _left)) {
    if (menu_selection<0) menu_selection=0;
    else if (menu_page=="options" && menu_buttons[menu_selection].action=="sensitivity" && (_right || _left)) {
        global.mouse_sensitivity=clamp(global.mouse_sensitivity+(_right ? .1 : -.1),
            global.P.menu.slider.min,global.P.menu.slider.max);
        bb_settings_save();
    } else if (_next || _right) menu_selection=(menu_selection+1) mod _count;
    else menu_selection=(menu_selection+_count-1) mod _count;
}
if (menu_page=="options") {
    var _slider=global.P.menu.slider;
    if (_clicked && _mx>=_slider.hit[0] && _mx<=_slider.hit[0]+_slider.hit[2]
        && _my>=_slider.hit[1] && _my<=_slider.hit[1]+_slider.hit[3]) menu_drag_slider=true;
    if (menu_drag_slider) {
        var _amount=clamp((_mx-_slider.track[0])/(_slider.track[1]-_slider.track[0]),0,1);
        global.mouse_sensitivity=lerp(_slider.min,_slider.max,_amount);
        if (!mouse_check_button(mb_left)) {menu_drag_slider=false;bb_settings_save();}
    }
} else menu_drag_slider=false;
if ((keyboard_check_pressed(vk_enter) && !keyboard_check(vk_alt)) || keyboard_check_pressed(vk_space)) _activate=true;
var _action=(_activate && menu_selection>=0)?menu_buttons[menu_selection].action:"";
if (keyboard_check_pressed(vk_escape) && menu_page!="title") _action=bb_menu_back_page(menu_page);
switch (_action) {
    case "story": bb_start_mode("story");break;
    case "endless": bb_start_mode("endless");break;
    case "quit": game_end();break;
    case "rumble": global.rumble_enabled=!global.rumble_enabled;bb_settings_save();break;
    case "analog": global.analog_movement=!global.analog_movement;bb_settings_save();break;
    case "sensitivity": break;
    default:
        if (_action!="") { menu_page=_action;menu_selection=-1;menu_buttons=bb_menu_layout(menu_page); }
        break;
}
