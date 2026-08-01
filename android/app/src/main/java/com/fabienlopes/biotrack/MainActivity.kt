package com.fabienlopes.biotrack

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.runtime.collectAsState
import com.fabienlopes.biotrack.data.BioTrackViewModel
import com.fabienlopes.biotrack.notifications.ReminderScheduler
import com.fabienlopes.biotrack.ui.BioTrackApp
import com.fabienlopes.biotrack.ui.BioTrackTheme

class MainActivity : ComponentActivity() {
    private val viewModel: BioTrackViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        ReminderScheduler.createChannel(this)
        setContent {
            BioTrackTheme(darkTheme = viewModel.darkMode.collectAsState().value) {
                BioTrackApp(viewModel)
            }
        }
    }
}
