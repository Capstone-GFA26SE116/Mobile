import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/metanoia_logo.dart';
import '../data/auth_repository.dart';
import '../widgets/auth_hero_card.dart';
import 'auth_gate.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthRepository _authRepository = AuthRepository();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _rememberMe = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Xử lý sự kiện đăng nhập Google
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final authResponse = await _authRepository.signInWithGoogle();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xin chào, ${authResponse.fullName}!'),
          backgroundColor: AppColors.voltagentPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Điều hướng tới AuthGate để kiểm tra Onboarding / MainShell
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleManualLogin() {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.voltagentHairline),
        ),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.voltagentPrimary),
            SizedBox(width: 8),
            Text(
              'Cổng Đăng Nhập METANOIA',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Đăng nhập thủ công qua Email đang trong lộ trình phát triển của hệ thống. Bạn có thể sử dụng "Tiếp tục với Google" để đăng nhập và tự động đồng bộ lịch trình ngay lập tức.\n\nBạn có muốn đăng nhập bằng Google ngay bây giờ?',
          style: TextStyle(color: AppColors.voltagentBody, fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Để sau', style: TextStyle(color: AppColors.voltagentMute)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleGoogleSignIn();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.voltagentPrimary,
              foregroundColor: AppColors.voltagentOnPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Tiếp tục với Google', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voltagentCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(),
              const SizedBox(height: 22),
              const AuthHeroCard(),
              const SizedBox(height: 26),
              _buildLoginForm(),
              const SizedBox(height: 28),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const MetanoiaLogo(size: 30),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.voltagentPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.voltagentPrimary.withOpacity(0.3)),
              ),
              child: const Text(
                'v2.4 Cognitive Engine',
                style: TextStyle(
                  color: AppColors.voltagentPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            );
          },
          child: RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 12.5),
              children: [
                TextSpan(
                  text: 'Chưa có tài khoản? ',
                  style: TextStyle(color: AppColors.voltagentBody),
                ),
                TextSpan(
                  text: 'Đăng ký ngay',
                  style: TextStyle(
                    color: AppColors.voltagentPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.voltagentHairline),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pill Eyebrow Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.voltagentPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.voltagentPrimary.withOpacity(0.35)),
              ),
              child: const Text(
                'CỔNG ĐĂNG NHẬP',
                style: TextStyle(
                  color: AppColors.voltagentPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Chào mừng trở lại',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tiếp tục tối ưu hóa thời gian và năng lượng làm việc của bạn.',
              style: TextStyle(
                color: AppColors.voltagentBody,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Google SSO Button
            _buildGoogleButton(),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle, color: AppColors.voltagentPrimary, size: 7),
                SizedBox(width: 6),
                Text(
                  'Đồng bộ tức thì Google Calendar',
                  style: TextStyle(
                    color: AppColors.voltagentMute,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Divider "HOẶC VỚI EMAIL"
            Row(
              children: [
                const Expanded(child: Divider(color: AppColors.voltagentHairline, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'HOẶC VỚI EMAIL',
                    style: TextStyle(
                      color: AppColors.voltagentMute,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: AppColors.voltagentHairline, thickness: 1)),
              ],
            ),
            const SizedBox(height: 20),

            // Email Field
            _buildLabel('Email'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _buildInputDecoration(
                hintText: 'nguyenvana@gmail.com',
                suffixIcon: const Icon(Icons.alternate_email, color: AppColors.voltagentMute, size: 18),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                if (!v.contains('@') || !v.contains('.')) return 'Email không hợp lệ';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Mật khẩu Field
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel('Mật khẩu'),
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng liên hệ quản trị viên hoặc sử dụng Google SSO để khôi phục tài khoản.'),
                        backgroundColor: AppColors.voltagentPrimary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text(
                    'Quên mật khẩu?',
                    style: TextStyle(
                      color: AppColors.voltagentPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: !_showPassword,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _buildInputDecoration(
                hintText: '••••••••••••',
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.voltagentMute,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
            ),
            const SizedBox(height: 14),

            // Checkbox Ghi nhớ
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _rememberMe,
                    activeColor: AppColors.voltagentPrimary,
                    checkColor: AppColors.voltagentOnPrimary,
                    side: const BorderSide(color: AppColors.voltagentHairlineLight),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (v) => setState(() => _rememberMe = v ?? true),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Ghi nhớ phiên đăng nhập trên thiết bị này',
                  style: TextStyle(color: AppColors.voltagentBody, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Nút Đăng nhập CTA
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _handleManualLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.voltagentPrimary,
                  foregroundColor: AppColors.voltagentOnPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Đăng nhập vào Không gian làm việc',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return InkWell(
      onTap: _isLoading ? null : _handleGoogleSignIn,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.voltagentCanvasSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.voltagentHairlineLight),
        ),
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(FontAwesomeIcons.google, size: 16, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text(
                    'Tiếp tục với Google',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.voltagentBody,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hintText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 13),
      filled: true,
      fillColor: AppColors.voltagentCanvasSoft,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.voltagentHairlineLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.voltagentHairlineLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.voltagentPrimary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.redAccent.shade200),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, color: AppColors.voltagentPrimary, size: 7),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Dành riêng cho sinh viên kỹ thuật, nghiên cứu sinh và các chuyên gia độc lập.',
                style: TextStyle(color: AppColors.voltagentMute, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Được bảo vệ bởi giao thức ẩn danh hóa dữ liệu METANOIA. Không quảng cáo, không thương mại hóa dữ liệu cá nhân.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF555555),
            fontSize: 10.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}