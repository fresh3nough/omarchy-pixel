package com.omarchy.launcher;
import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
public class MainActivity extends Activity {
  protected void onCreate(Bundle b) {
    super.onCreate(b);
    Intent i = new Intent();
    i.setClassName("com.termux", "com.termux.app.RunCommandService");
    i.setAction("com.termux.RUN_COMMAND");
    i.putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/home/.shortcuts/Omarchy.sh");
    i.putExtra("com.termux.RUN_COMMAND_BACKGROUND", true);
    i.putExtra("com.termux.RUN_COMMAND_SESSION", false);
    startService(i);
    finish();
  }
}
