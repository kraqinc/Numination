package com.wren.ide

import android.content.Intent
import android.os.Bundle
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.ImageView
import androidx.activity.ComponentActivity
import androidx.core.view.WindowCompat

class SplashActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        setContentView(R.layout.activity_splash)

        window.statusBarColor = android.graphics.Color.parseColor("#F8F5F0")
        window.navigationBarColor = android.graphics.Color.parseColor("#F8F5F0")
        WindowCompat.getInsetsController(window, window.decorView).apply {
            isAppearanceLightStatusBars = true
            isAppearanceLightNavigationBars = true
        }

        val logo = findViewById<ImageView>(R.id.logoImage)
        val dot = findViewById<android.view.View>(R.id.claudeDot)

        logo.alpha = 1f
        dot.alpha = 0f

        logo.post {
            dot.post {
                val dotX = logo.x + (logo.width * 0.52f) - (dot.width / 2f)
                val dotY = logo.y + (logo.height * 0.18f) - (dot.height / 2f)

                dot.x = dotX
                dot.y = dotY
                dot.translationY = 0f
                dot.alpha = 0f
                dot.scaleX = 0.6f
                dot.scaleY = 0.6f

                dot.animate()
                    .alpha(1f)
                    .scaleX(1f)
                    .scaleY(1f)
                    .setDuration(420L)
                    .setInterpolator(AccelerateDecelerateInterpolator())
                    .start()

                dot.animate()
                    .translationYBy(-18f)
                    .setDuration(1100L)
                    .setInterpolator(AccelerateDecelerateInterpolator())
                    .start()

                logo.animate()
                    .alpha(0f)
                    .setStartDelay(900L)
                    .setDuration(650L)
                    .setInterpolator(AccelerateDecelerateInterpolator())
                    .withEndAction {
                        startActivity(
                            Intent(this, MainActivity::class.java).apply {
                                if (intent?.data != null) data = intent.data
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                            }
                        )
                        overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out)
                        finish()
                    }
                    .start()
            }
        }
    }
}
