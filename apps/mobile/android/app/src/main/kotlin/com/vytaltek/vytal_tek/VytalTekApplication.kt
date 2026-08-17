package com.vytaltek.vytal_tek

import android.app.Application
import com.vytaltek.vytal_tek.qring.QRingSdkHost

class VytalTekApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        QRingSdkHost.init(this)
    }
}
