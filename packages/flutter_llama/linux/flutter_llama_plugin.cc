#include "include/flutter_llama/flutter_llama_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <cstring>

#define FLUTTER_LLAMA_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_llama_plugin_get_type(), \
                              FlutterLlamaPlugin))

struct _FlutterLlamaPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(FlutterLlamaPlugin, flutter_llama_plugin, g_object_get_type())

static void flutter_llama_plugin_handle_method_call(
    FlutterLlamaPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    g_autofree gchar* version = g_strdup("Linux (FFI Supported)");
    g_autoptr(FlValue) result = fl_value_new_string(version);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void flutter_llama_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(flutter_llama_plugin_parent_class)->dispose(object);
}

static void flutter_llama_plugin_class_init(FlutterLlamaPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = flutter_llama_plugin_dispose;
}

static void flutter_llama_plugin_init(FlutterLlamaPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  FlutterLlamaPlugin* plugin = FLUTTER_LLAMA_PLUGIN(user_data);
  flutter_llama_plugin_handle_method_call(plugin, method_call);
}

void flutter_llama_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FlutterLlamaPlugin* plugin = FLUTTER_LLAMA_PLUGIN(
      g_object_new(flutter_llama_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "flutter_llama",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
