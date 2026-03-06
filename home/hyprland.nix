{ lib, osConfig, pkgs, ... }:

let
  thisMachineIsPersonal = osConfig.thisMachine.hasRole."personal";
in
{
  config = lib.mkIf thisMachineIsPersonal {
    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = false; # Required when using UWSM

      settings = {
        "$mod" = "SUPER";
        "$terminal" = "ghostty";
        "$menu" = "wofi --show drun";

        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
          "col.inactive_border" = "rgba(595959aa)";
          layout = "dwindle";
        };

        decoration = {
          rounding = 10;

          blur = {
            enabled = true;
            size = 3;
            passes = 1;
          };

          shadow = {
            enabled = true;
            range = 4;
            render_power = 3;
            color = "rgba(1a1a1aee)";
          };
        };

        animations = {
          enabled = true;
          bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
          animation = [
            "windows, 1, 7, myBezier"
            "windowsOut, 1, 7, default, popin 80%"
            "border, 1, 10, default"
            "borderangle, 1, 8, default"
            "fade, 1, 7, default"
            "workspaces, 1, 6, default"
          ];
        };

        dwindle = {
          pseudotile = true;
          preserve_split = true;
        };

        input = {
          follow_mouse = 1;
          touchpad = {
            natural_scroll = true;
          };
        };

        misc = {
          force_default_wallpaper = 0;
        };

        bind = [
          # Applications
          "$mod, Return, exec, $terminal"
          "$mod, D, exec, $menu"
          "$mod, L, exec, hyprlock"

          # Window management
          "$mod, Q, killactive"
          "$mod, F, fullscreen"
          "$mod, V, togglefloating"
          "$mod, P, pseudo"
          "$mod, J, togglesplit"

          # Move focus
          "$mod, left, movefocus, l"
          "$mod, right, movefocus, r"
          "$mod, up, movefocus, u"
          "$mod, down, movefocus, d"

          # Switch workspaces
          "$mod, 1, workspace, 1"
          "$mod, 2, workspace, 2"
          "$mod, 3, workspace, 3"
          "$mod, 4, workspace, 4"
          "$mod, 5, workspace, 5"
          "$mod, 6, workspace, 6"
          "$mod, 7, workspace, 7"
          "$mod, 8, workspace, 8"
          "$mod, 9, workspace, 9"
          "$mod, 0, workspace, 10"

          # Move active window to workspace
          "$mod SHIFT, 1, movetoworkspace, 1"
          "$mod SHIFT, 2, movetoworkspace, 2"
          "$mod SHIFT, 3, movetoworkspace, 3"
          "$mod SHIFT, 4, movetoworkspace, 4"
          "$mod SHIFT, 5, movetoworkspace, 5"
          "$mod SHIFT, 6, movetoworkspace, 6"
          "$mod SHIFT, 7, movetoworkspace, 7"
          "$mod SHIFT, 8, movetoworkspace, 8"
          "$mod SHIFT, 9, movetoworkspace, 9"
          "$mod SHIFT, 0, movetoworkspace, 10"

          # Scroll through workspaces
          "$mod, mouse_down, workspace, e+1"
          "$mod, mouse_up, workspace, e-1"

          # Screenshots
          ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
          "SHIFT, Print, exec, grim - | wl-copy"

          # Clipboard history
          "$mod SHIFT, V, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy"
        ];

        bindm = [
          # Move/resize with mouse
          "$mod, mouse:272, movewindow"
          "$mod, mouse:273, resizewindow"
        ];

        bindel = [
          # Volume
          ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
          ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"

          # Brightness
          ", XF86MonBrightnessUp, exec, brightnessctl s 10%+"
          ", XF86MonBrightnessDown, exec, brightnessctl s 10%-"
        ];

        bindl = [
          ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ];

        exec-once = [
          "waybar"
          "mako"
          "hyprpaper"
          "wl-paste --type text --watch cliphist store"
          "wl-paste --type image --watch cliphist store"
        ];
      };
    };

    # Waybar
    programs.waybar = {
      enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          height = 30;
          modules-left = [ "hyprland/workspaces" ];
          modules-center = [ "clock" ];
          modules-right = [ "network" "pulseaudio" "battery" "tray" ];

          clock = {
            format = "{:%H:%M  %Y-%m-%d}";
          };

          battery = {
            format = "{capacity}% {icon}";
            format-icons = [ "" "" "" "" "" ];
          };

          network = {
            format-wifi = "{essid} ({signalStrength}%) ";
            format-ethernet = "{ipaddr}/{cidr} ";
            format-disconnected = "Disconnected ";
          };

          pulseaudio = {
            format = "{volume}% {icon}";
            format-muted = "";
            format-icons = {
              default = [ "" "" "" ];
            };
            on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          };

          tray = {
            spacing = 10;
          };
        };
      };
    };

    # Notifications
    services.mako = {
      enable = true;
      settings = {
        default-timeout = 5000;
        border-radius = 5;
      };
    };

    # Idle daemon
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch dpms on";
        };

        listener = [
          {
            timeout = 300;
            on-timeout = "loginctl lock-session";
          }
          {
            timeout = 330;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
          {
            timeout = 1800;
            on-timeout = "systemctl suspend";
          }
        ];
      };
    };

    # Lock screen
    programs.hyprlock = {
      enable = true;
      settings = {
        general = {
          hide_cursor = true;
          grace = 5;
        };

        background = [
          {
            monitor = "";
            color = "rgba(25, 20, 20, 1.0)";
            blur_passes = 2;
            blur_size = 7;
          }
        ];

        input-field = [
          {
            monitor = "";
            size = "200, 50";
            outline_thickness = 3;
            dots_size = 0.33;
            dots_spacing = 0.15;
            outer_color = "rgb(151515)";
            inner_color = "rgb(200, 200, 200)";
            font_color = "rgb(10, 10, 10)";
            fade_on_empty = true;
            placeholder_text = "<i>Password...</i>";
            hide_input = false;
            position = "0, -20";
            halign = "center";
            valign = "center";
          }
        ];
      };
    };
  };
}
