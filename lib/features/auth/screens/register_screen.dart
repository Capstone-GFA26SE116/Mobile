import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/metanoia_logo.dart';
import '../data/auth_repository.dart';
import '../widgets/auth_hero_card.dart';
import 'auth_gate.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthRepository _authRepository = AuthRepository();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final authResponse = await _authRepository.signInWithGoogle();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chào mừng ${authResponse.fullName} đến với Metanoia!'),
          backgroundColor: AppColors.voltagentPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
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

  void _handleManualRegister() {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đồng ý với Điều khoản dịch vụ và Chính sách bảo mật.'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
              'Cổng Đăng Ký METANOIA',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Đăng ký tài khoản thủ công bằng Email đang được hoàn thiện ở Backend. Hiện tại hệ thống hỗ trợ kích hoạt không gian làm việc tức thì thông qua "Đăng ký với Google".\n\nBạn có muốn đăng ký nhanh với Google ngay bây giờ?',
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
            child: const Text('Đăng ký bằng Google', style: TextStyle(fontWeight: FontWeight.bold)),
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
              _buildRegisterForm(),
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
          onTap: () => Navigator.of(context).pop(),
          child: RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 12.5),
              children: [
                TextSpan(
                  text: 'Đã có tài khoản? ',
                  style: TextStyle(color: AppColors.voltagentBody),
                ),
                TextSpan(
                  text: 'Đăng nhập',
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

  Widget _buildRegisterForm() {
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
                'CỔNG ĐĂNG KÝ',
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
              'Tạo không gian làm việc',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Chỉ mất một phút. Lịch thông minh sẽ bắt đầu học thói quen của bạn từ ngày đầu tiên.',
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

            // Họ và tên
            _buildLabel('Họ và tên'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _buildInputDecoration(
                hintText: 'Nguyễn Văn A',
                suffixIcon: const Icon(Icons.person_outline, color: AppColors.voltagentMute, size: 18),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ và tên' : null,
            ),
            const SizedBox(height: 14),

            // Email
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

            // Mật khẩu
            _buildLabel('Mật khẩu'),
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
              validator: (v) {
                if (v == null || v.length < 8) return 'Mật khẩu phải có ít nhất 8 ký tự';
                return null;
              },
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4, left: 2),
              child: Text(
                'Ít nhất 8 ký tự.',
                style: TextStyle(color: AppColors.voltagentMute, fontSize: 11),
              ),
            ),
            const SizedBox(height: 14),

            // Xác nhận mật khẩu
            _buildLabel('Xác nhận mật khẩu'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _buildInputDecoration(
                hintText: '••••••••••••',
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.voltagentMute,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                ),
              ),
              validator: (v) {
                if (v != _passwordController.text) return 'Mật khẩu xác nhận không khớp';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Checkbox Terms
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _agreedToTerms,
                    activeColor: AppColors.voltagentPrimary,
                    checkColor: AppColors.voltagentOnPrimary,
                    side: const BorderSide(color: AppColors.voltagentHairlineLight),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: AppColors.voltagentBody, fontSize: 12, height: 1.4),
                      children: [
                        TextSpan(text: 'Tôi đồng ý với '),
                        TextSpan(
                          text: 'Điều khoản dịch vụ',
                          style: TextStyle(color: AppColors.voltagentPrimary, fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: ' và '),
                        TextSpan(
                          text: 'Chính sách bảo mật',
                          style: TextStyle(color: AppColors.voltagentPrimary, fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: ' của METANOIA.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Nút Tạo tài khoản CTA
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _handleManualRegister,
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
                      'Tạo tài khoản',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
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
                    'Đăng ký với Google',
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
