package com.jossephus.sample_android_odiff

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.MediaStore
import android.widget.Toast
import java.net.URLEncoder
import java.net.URLDecoder
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import coil3.compose.rememberAsyncImagePainter
import com.jossephus.android_diff.CDiffOptions
import com.jossephus.android_diff.ODiffLib
import com.jossephus.sample_android_odiff.ui.theme.TestOdiff_2Theme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            TestOdiff_2Theme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    AppContent(modifier = Modifier.padding(innerPadding))
                }
            }
        }
    }
}

@Composable
fun AppContent(modifier: Modifier = Modifier) {
    var beforeImageUri by remember { mutableStateOf<Uri?>(null) }
    var afterImageUri by remember { mutableStateOf<Uri?>(null) }

    val context = LocalContext.current

    val beforeLauncher =
        rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            if (result.resultCode == Activity.RESULT_OK) {
                beforeImageUri = result.data?.data
            }
        }

    val afterLauncher =
        rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            if (result.resultCode == Activity.RESULT_OK) {
                afterImageUri = result.data?.data
            }
        }

    val navController = rememberNavController()

    NavHost(navController = navController, startDestination = "main") {
        composable("main") {
            MainScreen(
                modifier = modifier,
                beforeImageUri = beforeImageUri,
                afterImageUri = afterImageUri,
                onSelectBefore = {
                    val intent =
                        Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
                    beforeLauncher.launch(intent)
                },
                onSelectAfter = {
                    val intent =
                        Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
                    afterLauncher.launch(intent)
                },
                onComputeDiff = {
                    val before = beforeImageUri
                    val after = afterImageUri

                    if (before == null || after == null) {
                        Toast.makeText(context, "Please select both images", Toast.LENGTH_SHORT)
                            .show()
                        return@MainScreen
                    }

                    val beforePath = getRealPathFromUri(context, before)
                    val afterPath = getRealPathFromUri(context, after)

                    if (beforePath == null || afterPath == null) {
                        Toast.makeText(context, "Unable to get file paths", Toast.LENGTH_SHORT)
                            .show()
                        return@MainScreen
                    }

                    val options = CDiffOptions()
                    val random = Math.random()
                    val resultCode = ODiffLib.odiff_diff(
                        beforePath,
                        afterPath,
                        context.cacheDir.resolve("diff_output_${random}.png").absolutePath,
                        options
                    )

                    if (resultCode != 0) {
                        Toast.makeText(
                            context,
                            "Diff failed with code $resultCode",
                            Toast.LENGTH_SHORT
                        )
                            .show()
                    } else {
                        val diffPath =
                            context.cacheDir.resolve("diff_output_${random}.png").absolutePath
                        val encodedPath = URLEncoder.encode(diffPath, "UTF-8")
                        navController.navigate("diff/$encodedPath")
                    }
                }
            )
        }
        composable("diff/{path}") { backStackEntry ->
            val encodedPath = backStackEntry.arguments?.getString("path")
            val path = encodedPath?.let { URLDecoder.decode(it, "UTF-8") }
            DiffScreen(diffImagePath = path)
        }
    }
}

fun getRealPathFromUri(context: Context, uri: Uri): String? {
    val projection = arrayOf(MediaStore.Images.Media.DATA)
    context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
        val columnIndex = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATA)
        if (cursor.moveToFirst()) {
            return cursor.getString(columnIndex)
        }
    }
    return null
}


@Composable
fun MainScreen(
    modifier: Modifier = Modifier,
    beforeImageUri: Uri?,
    afterImageUri: Uri?,
    onSelectBefore: () -> Unit,
    onSelectAfter: () -> Unit,
    onComputeDiff: () -> Unit
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Before Image", style = MaterialTheme.typography.headlineSmall)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(8.dp))
                .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(8.dp)),
            contentAlignment = Alignment.Center
        ) {
            val beforeUri = beforeImageUri
            if (beforeUri != null) {
                Image(
                    painter = rememberAsyncImagePainter(beforeUri),
                    contentDescription = "Before Image",
                    modifier = Modifier
                        .fillMaxSize()
                        .clickable {
                            onSelectBefore()
                        },
                    contentScale = ContentScale.Fit
                )
            } else {
                Button(
                    onClick = onSelectBefore,
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("Select Before Image")
                }
            }
        }

        Text("After Image", style = MaterialTheme.typography.headlineSmall)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(8.dp))
                .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(8.dp)),
            contentAlignment = Alignment.Center
        ) {
            val afterUri = afterImageUri
            if (afterUri != null) {
                Image(
                    painter = rememberAsyncImagePainter(afterUri),
                    contentDescription = "After Image",
                    modifier = Modifier
                        .fillMaxSize()
                        .clickable {
                            onSelectAfter()
                        },
                    contentScale = ContentScale.Fit
                )
            } else {
                Button(
                    onClick = onSelectAfter,
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("Select After Image")
                }
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        Button(
            onClick = onComputeDiff,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(8.dp)
        ) {
            Text("Diff Image")
        }
    }
}

@Composable
fun Greeting(name: String, modifier: Modifier = Modifier) {
    Text(
        text = "Hello $name!",
        modifier = modifier
    )
}

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    TestOdiff_2Theme {
        Greeting("Android")
    }
}


@Preview(showBackground = true)
@Composable
fun MainScreenPreview() {
    TestOdiff_2Theme {
        MainScreen(
            beforeImageUri = null,
            afterImageUri = null,
            onSelectBefore = {},
            onSelectAfter = {},
            onComputeDiff = {}
        )
    }
}

