import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Pages/Tact_Seller.dart';

class VerificationScreen extends StatefulWidget {
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
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _currentCode {
    return _controllers.map((c) => c.text).join();
  }

  void _verifyCode() async {
    // Unfocus all fields
    for (var node in _focusNodes) {
      node.unfocus();
    }

    String code = _currentCode;
    if (code.length != 6) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(Duration(seconds: 1));

    if (code == widget.expectedCode) {
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
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification Successful!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "Wrong code, please try again.";
        for (var controller in _controllers) {
          controller.clear();
        }
      });
      _focusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Email Verification'),
        backgroundColor: color.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.mark_email_read_outlined,
                size: 80,
                color: color.primaryColor,
              ),
              SizedBox(height: 20),
              Text(
                'Enter Verification Code',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color.cardColor,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'A 6-digit code was sent to this email. ${widget.email}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: SizedBox(
                      width: 50,
                      height: 60,
                      // 1. WRAP WITH KEYBOARD LISTENER FOR BACKSPACE DETECTION
                      child: KeyboardListener(
                        focusNode:
                            FocusNode(), // Required but not used directly
                        onKeyEvent: (event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey ==
                                  LogicalKeyboardKey.backspace) {
                            // If the field is empty and user hits backspace, go back
                            if (_controllers[index].text.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                          }
                        },
                        child: TextFormField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          autofocus: index == 0,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            // 2. REMOVED LengthLimitingTextInputFormatter(1) TO ALLOW PASTE
                          ],
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            counterText: "",
                            contentPadding: EdgeInsets.zero,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: color.hintColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: color.primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            if (_errorMessage != null) {
                              setState(() {
                                _errorMessage = null;
                              });
                            }

                            // 3. PASTE LOGIC
                            if (value.length == 6) {
                              // Distribute the pasted digits
                              for (int i = 0; i < 6; i++) {
                                _controllers[i].text = value[i];
                              }
                              // Submit
                              _verifyCode();
                            }
                            // 4. STANDARD TYPING LOGIC
                            else if (value.length == 1) {
                              if (index < 5) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(_focusNodes[index + 1]);
                              } else {
                                _focusNodes[index].unfocus();
                                _verifyCode();
                              }
                            }
                            // 5. HANDLE OVERFLOW (User types 2nd digit without moving)
                            else if (value.length > 1) {
                              // Keep only the last digit entered
                              _controllers[index].text = value.substring(
                                value.length - 1,
                              );
                              // Move next
                              if (index < 5) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(_focusNodes[index + 1]);
                              }
                            }
                            // 6. EMPTY/BACKSPACE LOGIC (When text existed and was deleted)
                            else if (value.isEmpty) {
                              if (index > 0) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(_focusNodes[index - 1]);
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  );
                }),
              ),

              SizedBox(height: 20),

              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),

              SizedBox(height: 30),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.hintColor.withOpacity(0.4),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: (_isLoading)
                    ? null
                    : () {
                        if (_currentCode.length == 6) {
                          _verifyCode();
                        }
                      },
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
                onPressed: () async {
                  isIOSPlatform
                      ? Api().showIosLoading(context)
                      : Api().showLoading(context);
                  String code = Api().generateVerificationCode();
                  print('here is the code $code');
                  // 2. Send the email

                  bool emailSent = await Api().sendEmail(
                    widget.email,
                    'Your Account Verification code',

                    """
Hello ${widget.name} ${widget.surname},

Thank you for signing up! 
Your 6-digit verification code is: $code

This code expires soon.
If you didn't request this, you can safely ignore this email.
          """,
                    context,
                  );

                  if (emailSent) {
                    Navigator.pop(context);
                    Api().showMessage(
                      context,
                      "Email Send Successfully",
                      "Success",
                      color.splashColor,
                    );
                  } else {
                    Navigator.pop(context);
                    Api().showMessage(
                      context,
                      "Email did not send!!, incorrect email",
                      "Error",
                      color.primaryColorDark,
                    );
                  }
                },

                child: Text(
                  "Didn't receive the code? Resend",
                  style: TextStyle(color: color.primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
