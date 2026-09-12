package com.example.myfirstapp;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.TextView;

public class MainActivity extends Activity implements Runnable {

    static {
        System.loadLibrary("native");
    }

    public native String getMessage();

    private TextView output;
    private final Handler handler = new Handler(Looper.getMainLooper());

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        output = (TextView) findViewById(R.id.output);
        
      
        handler.post(this);
    }

    @Override
    public void run() {
        if (output != null) {
            output.setText(getMessage());
        }
       
        handler.postDelayed(this, 1000);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        handler.removeCallbacks(this);
    }
}