#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Forward declaration
static void setup_linux_application_icon(GtkWindow* window);

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  GtkWindow* window = GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  setup_linux_application_icon(window);
  gtk_widget_show(GTK_WIDGET(window));
}

// Set application window and desktop launcher icons for Linux desktop environments
static void setup_linux_application_icon(GtkWindow* window) {
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  g_autofree gchar* exe_dir = (exe_path != nullptr) ? g_path_get_dirname(exe_path) : nullptr;

  g_autofree gchar* exe_asset_icon = (exe_dir != nullptr)
      ? g_build_filename(exe_dir, "data", "flutter_assets", "assets", "images", "aegis_logo.png", nullptr)
      : nullptr;
  g_autofree gchar* exe_data_icon = (exe_dir != nullptr)
      ? g_build_filename(exe_dir, "data", "aegis_logo.png", nullptr)
      : nullptr;

  const gchar* icon_candidates[] = {
    exe_asset_icon,
    exe_data_icon,
    "data/flutter_assets/assets/images/aegis_logo.png",
    "data/aegis_logo.png",
    "assets/images/aegis_logo.png",
    "linux/runner/aegis_logo.png",
    nullptr
  };

  const gchar* resolved_icon = nullptr;
  for (int i = 0; icon_candidates[i] != nullptr; i++) {
    if (icon_candidates[i] != nullptr && g_file_test(icon_candidates[i], G_FILE_TEST_EXISTS)) {
      resolved_icon = icon_candidates[i];
      break;
    }
  }

  if (resolved_icon != nullptr) {
    GError* err = nullptr;
    g_autoptr(GdkPixbuf) main_pixbuf = gdk_pixbuf_new_from_file(resolved_icon, &err);
    if (main_pixbuf != nullptr) {
      const int target_sizes[] = {16, 24, 32, 48, 64, 128, 256, 512};
      GList* icon_list = nullptr;
      for (size_t s = 0; s < G_N_ELEMENTS(target_sizes); s++) {
        GdkPixbuf* scaled = gdk_pixbuf_scale_simple(
            main_pixbuf, target_sizes[s], target_sizes[s], GDK_INTERP_BILINEAR);
        if (scaled != nullptr) {
          icon_list = g_list_append(icon_list, scaled);
        }
      }
      if (icon_list != nullptr) {
        gtk_window_set_icon_list(window, icon_list);
        gtk_window_set_default_icon_list(icon_list);
        g_list_free_full(icon_list, g_object_unref);
      } else {
        gtk_window_set_icon(window, main_pixbuf);
        gtk_window_set_default_icon(main_pixbuf);
      }
    } else if (err) {
      g_clear_error(&err);
    }

    // Auto-register to user's local icon theme and desktop file if not already present
    const gchar* home_dir = g_get_home_dir();
    if (home_dir != nullptr) {
      g_autofree gchar* hicolor_dir = g_build_filename(home_dir, ".local", "share", "icons", "hicolor", nullptr);
      g_mkdir_with_parents(hicolor_dir, 0755);

      // Ensure index.theme exists in hicolor so gtk-update-icon-cache recognizes the theme
      g_autofree gchar* user_theme_index = g_build_filename(hicolor_dir, "index.theme", nullptr);
      if (!g_file_test(user_theme_index, G_FILE_TEST_EXISTS)) {
        if (g_file_test("/usr/share/icons/hicolor/index.theme", G_FILE_TEST_EXISTS)) {
          g_autoptr(GFile) src = g_file_new_for_path("/usr/share/icons/hicolor/index.theme");
          g_autoptr(GFile) dst = g_file_new_for_path(user_theme_index);
          g_file_copy(src, dst, G_FILE_COPY_NONE, nullptr, nullptr, nullptr, nullptr);
        }
      }

      // Populate multiple resolutions in hicolor theme
      const int icon_resolutions[] = {16, 24, 32, 48, 64, 128, 256, 512};
      for (size_t r = 0; r < G_N_ELEMENTS(icon_resolutions); r++) {
        g_autofree gchar* res_str = g_strdup_printf("%dx%d", icon_resolutions[r], icon_resolutions[r]);
        g_autofree gchar* res_dir = g_build_filename(hicolor_dir, res_str, "apps", nullptr);
        g_mkdir_with_parents(res_dir, 0755);

        g_autofree gchar* target_icon_path = g_build_filename(res_dir, "id.cethokaryo.aegis.png", nullptr);
        g_autofree gchar* target_short_icon = g_build_filename(res_dir, "aegis.png", nullptr);

        if (!g_file_test(target_icon_path, G_FILE_TEST_EXISTS) && main_pixbuf != nullptr) {
          g_autoptr(GdkPixbuf) scaled = gdk_pixbuf_scale_simple(
              main_pixbuf, icon_resolutions[r], icon_resolutions[r], GDK_INTERP_BILINEAR);
          if (scaled != nullptr) {
            gdk_pixbuf_save(scaled, target_icon_path, "png", nullptr, nullptr);
            gdk_pixbuf_save(scaled, target_short_icon, "png", nullptr, nullptr);
          }
        }
      }

      // Also ensure ~/.local/share/pixmaps has the icon for desktop environments that look there
      g_autofree gchar* pixmaps_dir = g_build_filename(home_dir, ".local", "share", "pixmaps", nullptr);
      g_mkdir_with_parents(pixmaps_dir, 0755);
      g_autofree gchar* pixmap_path = g_build_filename(pixmaps_dir, "id.cethokaryo.aegis.png", nullptr);
      if (!g_file_test(pixmap_path, G_FILE_TEST_EXISTS) && resolved_icon != nullptr) {
        g_autoptr(GFile) src = g_file_new_for_path(resolved_icon);
        g_autoptr(GFile) dst = g_file_new_for_path(pixmap_path);
        g_file_copy(src, dst, G_FILE_COPY_OVERWRITE, nullptr, nullptr, nullptr, nullptr);
      }

      // Register or update .desktop file in ~/.local/share/applications
      g_autofree gchar* user_apps_dir = g_build_filename(home_dir, ".local", "share", "applications", nullptr);
      g_autofree gchar* user_desktop_path = g_build_filename(user_apps_dir, "id.cethokaryo.aegis.desktop", nullptr);
      if (!g_file_test(user_desktop_path, G_FILE_TEST_EXISTS) && exe_path != nullptr) {
        g_mkdir_with_parents(user_apps_dir, 0755);
        gchar* desktop_content = g_strdup_printf(
            "[Desktop Entry]\n"
            "Version=1.0\n"
            "Type=Application\n"
            "Name=AEGIS\n"
            "Comment=Automated Enterprise Guardian for Infrastructure Systems\n"
            "Exec=%s %%u\n"
            "Icon=id.cethokaryo.aegis\n"
            "Terminal=false\n"
            "Categories=Utility;Security;Network;\n"
            "StartupWMClass=%s\n",
            exe_path, APPLICATION_ID);
        g_file_set_contents(user_desktop_path, desktop_content, -1, nullptr);
        g_free(desktop_content);
      }

      // Append user icon directories to default icon theme
      gtk_icon_theme_append_search_path(gtk_icon_theme_get_default(), hicolor_dir);
      gtk_icon_theme_append_search_path(gtk_icon_theme_get_default(), pixmaps_dir);
      gtk_icon_theme_rescan_if_needed(gtk_icon_theme_get_default());
    }
  }

  // Only bind themed icon name if the icon is present in the icon theme to avoid unsetting pixbuf
  if (gtk_icon_theme_has_icon(gtk_icon_theme_get_default(), APPLICATION_ID)) {
    gtk_window_set_icon_name(window, APPLICATION_ID);
    gtk_window_set_default_icon_name(APPLICATION_ID);
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "AEGIS");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "AEGIS");
  }

  gtk_window_set_default_size(window, 1280, 720);
  setup_linux_application_icon(window);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
