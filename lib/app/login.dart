import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jurnal_mengajar/app/dashboard_admin.dart';
import 'package:jurnal_mengajar/app/dashboard_guru.dart';
import 'package:jurnal_mengajar/app/register_google_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/register_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isHandlingGoogleAuth = false; // Cegah double-trigger
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  StreamSubscription<AuthState>? _authSubscription; // Simpan agar tidak GC

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    // Jika sudah ada session aktif (misal app resume dari background setelah OAuth),
    // langsung proses tanpa menunggu event
    final existingSession = _supabase.auth.currentSession;
    if (existingSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleGoogleLoginSuccess(existingSession);
      });
    }

    // Simpan subscription agar tidak garbage-collected
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      // Handle signedIn DAN tokenRefreshed (keduanya bisa jadi hasil OAuth)
      if ((event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.tokenRefreshed) &&
          session != null) {
        _handleGoogleLoginSuccess(session);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel(); // Batalkan listener saat widget destroy
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveSession(String token, String role) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    await prefs.setString('role', role);
  }

  /// Dipanggil setelah Google OAuth callback berhasil
  Future<void> _handleGoogleLoginSuccess(Session session) async {
    // Cegah double-trigger
    if (_isHandlingGoogleAuth) return;
    _isHandlingGoogleAuth = true;

    if (!mounted) {
      _isHandlingGoogleAuth = false;
      return;
    }

    try {
      final user = session.user;

      // Cek apakah user sudah punya profil di tabel profiles
      final List<dynamic> profileData = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id);

      if (!mounted) return;

      if (profileData.isNotEmpty) {
        final profile = profileData.first;
        final role = profile['role'];
        final namaLengkap = profile['nama_lengkap'];
        final jabatan = profile['jabatan'];
        final noTelp = profile['no_telp'];

        // Cek apakah semua field wajib sudah dilengkapi
        final isProfileComplete =
            namaLengkap != null &&
            namaLengkap.toString().isNotEmpty &&
            role != null &&
            role.toString().isNotEmpty &&
            jabatan != null &&
            jabatan.toString().isNotEmpty &&
            noTelp != null &&
            noTelp.toString().isNotEmpty;

        if (!isProfileComplete) {
          // Profil belum lengkap → arahkan ke form
          Get.offAll(() => const RegisterGooglePage());
          return;
        }

        // Profil sudah lengkap → simpan session & arahkan ke dashboard
        await _saveSession(session.accessToken, role);

        if (role == 'admin') {
          Get.offAll(() => const DashboardAdmin());
        } else if (role == 'guru') {
          Get.offAll(() => const DashboardGuru());
        }
      } else {
        // Belum ada profil → form lengkapi data
        Get.offAll(() => const RegisterGooglePage());
      }
    } catch (e) {
      debugPrint('Failed to fetch admin profile: $e');
      if (mounted) {
        Get.snackbar(
          'Error',
          'Gagal memproses login Google: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } finally {
      _isHandlingGoogleAuth = false;
    }
  }

  // ID Klien Web diambil dari file .env
  String get _webClientId => dotenv.env['WEB_CLIENT'] ?? '';

  Future<void> _loginWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final googleSignIn = GoogleSignIn.instance;

      // Initialize dengan configuration
      await googleSignIn.initialize(serverClientId: _webClientId);

      final googleUser = await googleSignIn.authenticate();
      if (googleUser == null) {
        // User membatalkan dialog login Google
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'Tidak dapat menemukan ID Token Google';
      }

      // Supabase hanya mewajibkan idToken untuk verifikasi
      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      // listener onAuthStateChange di initState akan secara otomatis
      // meng-handle proses validasi role setelah Supabase berhasil sign in
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // User membatalkan dialog sengaja → diam saja
        return;
      }
      Get.snackbar(
        'Google Auth Error',
        e.description ?? 'Terjadi kesalahan saat autentikasi Google',
        backgroundColor: MainColor.yellowError,
        colorText: Colors.white,
      );
    } on AuthException catch (e) {
      Get.snackbar(
        'Login Gagal',
        e.message,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal login dengan Google: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar(
        'Error',
        'Email dan Password harus diisi',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final List<dynamic> profileData = await _supabase
            .from('profiles')
            .select()
            .eq('id', response.user!.id);

        if (profileData.isNotEmpty) {
          final role = profileData.first['role'];
          final token = response.session?.accessToken ?? '';

          await _saveSession(token, role);

          Get.snackbar(
            'Success',
            'Login Berhasil',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );

          if (role == 'admin') {
            Get.offAll(() => const DashboardAdmin());
          } else if (role == 'guru') {
            Get.offAll(() => const DashboardGuru());
          } else {
            Get.snackbar(
              'Error',
              'Role tidak dikenal',
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
          }
        } else {
          Get.snackbar(
            'Error',
            'Data profil tidak ditemukan',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      }
    } on AuthException catch (error) {
      Get.snackbar(
        'Login Failed',
        error.message,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (error) {
      Get.snackbar(
        'Error',
        'Terjadi kesalahan yang tidak terduga',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MainColor.secondaryColor,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 40.0,
              ),
              decoration: BoxDecoration(
                color: MainColor.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Image.asset(
                    'assets/image/LogoJr.png',
                    width: 250,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 40),

                  // Email Field
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      filled: true,
                      fillColor: MainColor.primaryBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      hintStyle: TextStyle(
                        color: MainColor.secondaryText,
                        fontFamily: GoogleFonts.poppins().fontFamily,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      filled: true,
                      fillColor: MainColor.primaryBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      hintStyle: TextStyle(color: MainColor.secondaryText),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: MainColor.secondaryText,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MainColor.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Login',
                              style: TextStyle(
                                fontFamily: GoogleFonts.poppins().fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'atau',
                          style: TextStyle(
                            color: MainColor.secondaryText,
                            fontFamily: GoogleFonts.poppins().fontFamily,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Google Login Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isGoogleLoading ? null : _loginWithGoogle,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isGoogleLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.blue,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google logo colors icon
                                const _GoogleIcon(),
                                const SizedBox(width: 10),
                                Text(
                                  'Masuk dengan Google',
                                  style: TextStyle(
                                    fontFamily:
                                        GoogleFonts.poppins().fontFamily,
                                    color: MainColor.primaryText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Guru Baru? ',
                        style: TextStyle(
                          color: MainColor.secondaryText,
                          fontFamily: GoogleFonts.poppins().fontFamily,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Get.to(() => const RegisterPage());
                        },
                        child: Text(
                          'Daftar Disini',
                          style: TextStyle(
                            fontFamily: GoogleFonts.poppins().fontFamily,
                            color: MainColor.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom Google Icon dengan warna asli
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    // Background circle
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r, bgPaint);

    // Draw a simplified colorful G
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'G',
        style: TextStyle(
          fontSize: size.width * 0.85,
          fontWeight: FontWeight.bold,
          foreground: Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFF4285F4), Color(0xFF34A853)],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}
