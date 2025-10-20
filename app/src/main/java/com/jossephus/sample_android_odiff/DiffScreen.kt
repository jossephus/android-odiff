package com.jossephus.sample_android_odiff

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil3.compose.rememberAsyncImagePainter
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.material3.Scaffold
import java.io.File

@Composable
fun DiffScreen(diffImagePath: String?) {
    Scaffold { paddingValues ->

        Column(
            modifier = Modifier
                .padding(paddingValues)
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.Top,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(16.dp))

            Spacer(modifier = Modifier.height(24.dp))
            if (diffImagePath != null) {
                Image(
                    painter = rememberAsyncImagePainter(Uri.fromFile(File(diffImagePath))),
                    contentDescription = "Difference Image",
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth(),
                    contentScale = ContentScale.Fit
                )
            } else {
                Text("No difference image available", style = MaterialTheme.typography.bodyLarge)
            }
        }
    }
}
