package com.vtk21.myapp

import android.app.Application
import com.vtk21.myapp.hband.HBandSdkHost

class VytalTekApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        HBandSdkHost.init(this)
    }
}
