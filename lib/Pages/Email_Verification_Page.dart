import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ttact/Components/API.dart';

class VerificationScreen extends StatefulWidget {
  // Pass the code from your registration page so this screen knows what to check
  final String name;
  final String surname;
  final String email;
  final String password;
  final String address;
  final String contacts;
  final String selectedOverseerUid;
  final String role;
  final String accountNumber;
  final String bankCode;
  final String province;
  final String districtElder;
  final String communityName;
  final String expectedCode;

  const VerificationScreen({
    Key? key,
    required this.expectedCode,
    required this.name,
    required this.surname,
    required this.email,
    required this.password,
    required this.address,
    required this.contacts,
    required this.selectedOverseerUid,
    required this.role,
    required this.accountNumber,
    required this.bankCode,
    required this.province,
    required this.districtElder,
    required this.communityName,
  }) : super(key: key);

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Request focus for the hidden text field when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    // Listen to the controller to update the UI
    _controller.addListener(() {
      setState(() {
        // Clear error when user starts typing
        if (_errorMessage != null) {
          _errorMessage = null;
        }
      });

      // Auto-submit when 6 digits are entered
      if (_controller.text.length == 6) {
        _verifyCode();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _verifyCode() async {
    // Unfocus to hide keyboard
    _focusNode.unfocus();

    if (_controller.text.length != 6) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // --- This is where you check the code ---
    // We add a small delay to simulate a network call
    await Future.delayed(Duration(seconds: 1));

    if (_controller.text == widget.expectedCode) {
      // SUCCESS

      await Api().signUp(
        widget.name,
        widget.surname,
        widget.email,
        widget.password,
        widget.address,
        widget.contacts,
        widget.selectedOverseerUid!,
        widget.role!,
        accountNumber: widget.accountNumber,
        bankCode: widget.bankCode,
        widget.province!,
        widget.districtElder,
        widget.communityName!,
        context,
      );
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification Successful!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to your app's home screen
      // Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // FAILURE
      setState(() {
        _isLoading = false;
        // Set error message to make boxes red
        _errorMessage = "Wrong code, please try again.";
        _controller.clear(); // Clear the text
      });
      // Request focus again for the user to re-try
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text('Email Verification'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      // 1. --- REMOVED THE STACK WIDGET ---
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 2. --- MOVED THE HIDDEN TEXTFIELD HERE ---
              // It's the first child of the Column, but it's
              // invisible so it doesn't affect the layout.
              Offstage(
                offstage: true,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  autofocus: true,
                  style: TextStyle(color: Colors.transparent, fontSize: 1),
                  decoration: InputDecoration(border: InputBorder.none),
                ),
              ),

              // --- The rest of your UI is unchanged ---
              Icon(
                Icons.mark_email_read_outlined,
                size: 80,
                color: primaryColor,
              ),
              SizedBox(height: 20),
              Text(
                'Enter Verification Code',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'A 6-digit code was sent to this email. ${widget.email}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 40),

              // 3. The 6 OTP boxes
              GestureDetector(
                onTap: () {
                  _focusNode.requestFocus();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return _buildOtpBox(index, context);
                  }),
                ),
              ),

              SizedBox(height: 20),

              // 4. Error Message
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),

              SizedBox(height: 30),

              // 5. Verify Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: (_controller.text.length == 6 && !_isLoading)
                    ? _verifyCode
                    : null,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Verify',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  // Add your "Resend Code" logic here
                },
                child: Text(
                  "Didn't receive the code? Resend",
                  style: TextStyle(color: primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- This is the widget for a single OTP box ---
  Widget _buildOtpBox(int index, BuildContext context) {
    // Get the digit for this box, or an empty string
    final String digit = _controller.text.length > index
        ? _controller.text[index]
        : '';

    // Check if this box is the one currently being typed into
    final bool isFocused = _controller.text.length == index;

    // Check if there's an error
    final bool hasError = _errorMessage != null;

    Color borderColor;
    if (hasError) {
      borderColor = Colors.red;
    } else if (isFocused) {
      // Use your theme's primary color
      borderColor = Theme.of(context).primaryColor;
    } else if (digit.isNotEmpty) {
      borderColor = Colors.grey[600]!;
    } else {
      borderColor = Colors.grey[300]!;
    }

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          if (isFocused || hasError)
            BoxShadow(
              color: hasError
                  ? Colors.red.withOpacity(0.3)
                  : Theme.of(context).primaryColor.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Center(
        // --- THIS IS THE ANIMATION ---
        // When the 'digit' variable changes, it animates in and out
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (Widget child, Animation<double> animation) {
            // This is the "easeIn and Out" animation
            return ScaleTransition(scale: animation, child: child);
          },
          child: Text(
            digit,
            // We use a ValueKey to tell the AnimatedSwitcher that the
            // content has changed, which triggers the animation.
            key: ValueKey(digit),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
