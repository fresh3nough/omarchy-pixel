package com.omarchy.launcher;
import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
public class MainActivity extends Activity {
  protected void onCreate(Bundle b) {
    super.onCreate(b);
    Intent i = new Intent();
    i.setClassName("com.termux", "com.termux.app.RunCommandService");
    i.setAction("com.termux.RUN_COMMAND");
    i.putExtra("com.termux.RUN_COMMAND_PATH",
      "/data/data/com.termux/files/home/.shortcuts/Omarchy");
    i.putExtra("com.termux.RUN_COMMAND_BACKGROUND", true);
    i.putExtra("com.termux.RUN_COMMAND_SESSION", false);
    try { startService(i); } catch (Exception e) {}
    new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
      public void run() {
        try {
          Intent x = new Intent();
          x.setClassName("com.termux.x11", "com.termux.x11.MainActivity");
          x.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
          startActivity(x);
        } catch (Exception ignored) {}
        finish();
      }
    }, 1500);
  }
}
