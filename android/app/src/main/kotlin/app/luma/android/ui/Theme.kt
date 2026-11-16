package app.luma.android.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * 设计 token。数值来自 `spec/constants.json` 的 `design` 段，
 * 与 macOS / iOS 保持同一套：圆角 4/10/18，字号阶梯，按下 0.97。
 */
object LumaTokens {
    val RadiusSmall = 4.dp
    val RadiusMedium = 10.dp
    val RadiusLarge = 18.dp

    val Paper = Color(0xFFFBF7F0)
    val PaperDark = Color(0xFF141210)
    val Surface = Color(0xFFFFFFFF)
    val SurfaceDark = Color(0xFF1E1B18)
    val Accent = Color(0xFF2F6D8E)
    val Positive = Color(0xFF2F7D52)
    val Warning = Color(0xFF9A6A15)
    val Danger = Color(0xFFB3261E)

    val Body = 17.sp
    val Title = 22.sp
    val Display = 34.sp
    val Caption = 13.sp
}

private val LightColors = lightColorScheme(
    primary = LumaTokens.Accent,
    onPrimary = Color.White,
    background = LumaTokens.Paper,
    onBackground = Color(0xFF1A1714),
    surface = LumaTokens.Surface,
    onSurface = Color(0xFF1A1714),
    surfaceVariant = Color(0xFFF1ECE3),
    onSurfaceVariant = Color(0xFF514B44),
    surfaceContainerLowest = Color(0xFFFFFFFF),
    surfaceContainerLow = Color(0xFFF6F1E8),
    surfaceContainer = Color(0xFFF3EDE3),
    surfaceContainerHigh = Color(0xFFEDE6DA),
    surfaceContainerHighest = Color(0xFFE7DFD2),
    secondaryContainer = Color(0xFFE5DED1),
    onSecondaryContainer = Color(0xFF2A2620),
    error = LumaTokens.Danger,
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF7FB6D4),
    onPrimary = Color(0xFF10222B),
    background = LumaTokens.PaperDark,
    onBackground = Color(0xFFEDE6DC),
    surface = LumaTokens.SurfaceDark,
    onSurface = Color(0xFFEDE6DC),
    surfaceVariant = Color(0xFF2A2622),
    onSurfaceVariant = Color(0xFFB9B0A5),
    surfaceContainerLowest = Color(0xFF0E0C0A),
    surfaceContainerLow = Color(0xFF191614),
    surfaceContainer = Color(0xFF1E1B18),
    surfaceContainerHigh = Color(0xFF252220),
    surfaceContainerHighest = Color(0xFF2C2825),
    secondaryContainer = Color(0xFF332E29),
    onSecondaryContainer = Color(0xFFEDE6DC),
    error = Color(0xFFE4897F),
)

private val LumaTypography = Typography(
    displaySmall = TextStyle(fontSize = LumaTokens.Display, fontWeight = FontWeight.SemiBold),
    titleLarge = TextStyle(fontSize = LumaTokens.Title, fontWeight = FontWeight.SemiBold),
    titleMedium = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.Medium),
    bodyLarge = TextStyle(fontSize = LumaTokens.Body, lineHeight = 26.sp),
    bodyMedium = TextStyle(fontSize = 15.sp, lineHeight = 22.sp),
    labelMedium = TextStyle(fontSize = LumaTokens.Caption),
)

@Composable
fun LumaTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (dark) DarkColors else LightColors,
        typography = LumaTypography,
        content = content,
    )
}
