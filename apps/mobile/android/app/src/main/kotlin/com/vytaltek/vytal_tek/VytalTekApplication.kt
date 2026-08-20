package com.vytaltek.vytal_tek

import android.app.Application
import com.vytaltek.vytal_tek.hband.HBandSdkHost

class VytalTekApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        HBandSdkHost.init(this)
    }
}
