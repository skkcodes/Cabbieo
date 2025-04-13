import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:waygo/global/global_var.dart';
import 'package:waygo/screens/auth/signup_screen.dart';
import 'package:waygo/screens/costom%20widgets/costom_text_feild.dart';
import 'package:waygo/screens/costom%20widgets/loading_screen.dart';
import 'package:waygo/screens/costom%20widgets/terms_and_conditions.dart';
import 'package:waygo/screens/methods/common_methods.dart';
import 'package:waygo/screens/rider/home_rider_screen.dart';
import 'package:waygo/screens/rider/rider_navigation.dart';
import 'package:waygo/screens/welcome_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  CommonMethods cMethods=CommonMethods();
  
  TextEditingController emailTextEditingController = TextEditingController();
  TextEditingController passwordTextEditingController = TextEditingController();
  TextEditingController confirmPasswordTextEditingController =
      TextEditingController();

  checkInternetConnection(){
    
    loginFormValidation();
  }
  loginFormValidation(){
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
      .hasMatch(emailTextEditingController.text)) {
    cMethods.displaySnackBar("Please enter a valid email address", context);
    }else if (passwordTextEditingController.text.isEmpty) {
    cMethods.displaySnackBar("Please enter your password", context);
    }
    else {
      loginUser();
    }
    }
  loginUser() async{
    showDialog(context: context,barrierDismissible: false,builder: (BuildContext context) => LoadingScreen(messangeText: "Logging in..."));

    final User? userFirebase=(
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailTextEditingController.text.trim(), password: passwordTextEditingController.text.trim()
      ).catchError((errorMsg)
      {
        Navigator.pop(context);
        cMethods.displaySnackBar(errorMsg.toString(), context);
      })

    ).user;

    if(!context.mounted)return
    Navigator.pop(context);

    if(userFirebase!=null){
      DatabaseReference userRef = FirebaseDatabase.instance.ref().child("users").child(userFirebase.uid);

      await userRef.once().then((snap){
          if (snap.snapshot.value != null){
            if ((snap.snapshot.value as Map)["blockStatus"] == "no"){
              userName=(snap.snapshot.value as Map)["name"];
              email=(snap.snapshot.value as Map)["email"];
              Navigator.push(context, MaterialPageRoute(builder: (builder) => RiderNavigation()));

            }else{
              FirebaseAuth.instance.signOut();
              cMethods.displaySnackBar("You are blocked, Please contact support team. cabio.support@gmail.com", context);
              Navigator.pop(context);


            }

          }else{
            FirebaseAuth.instance.signOut();
            cMethods.displaySnackBar("Record not fount please signup first. ", context);
            Navigator.pop(context);
          }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Image.asset(
          "assets/logo/welcome.png",
          fit: BoxFit.cover,
          height: double.infinity,
          width: double.infinity,
        ),
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                SizedBox(
                  height: 20,
                ),
                Center(
                    child: SizedBox(
                  child: Image.asset(
                    "assets/logo/app_icon.png",
                    height: 200,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                )),
                SizedBox(
                  height: 10,
                ),
                Text(
                  "Login to continue...",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Padding(
                  padding: EdgeInsets.all(22),
                  child: Column(
                    children: [
                      
                      CustomTextField(
                          controller: emailTextEditingController,
                          labelText: "Email Address",
                          icon: Icons.mail),
                      SizedBox(
                        height: 22,
                      ),
                      CustomTextField(
                          controller: passwordTextEditingController,
                          labelText: "Password",
                          icon: Icons.password),
                      SizedBox(
                        height: 22,
                      ),

                      GestureDetector(
                        onTap: (){
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>HomeRiderScreen()));
                        },
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text("forget password",style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold
                          ),),
                        ),
                      ),

                      SizedBox(height: 22,),
                      ElevatedButton(
                        onPressed: () {
                          checkInternetConnection();
                          
                        },
                        child: Text('Login'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey.shade800,
                            textStyle: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold),
                            elevation: 10,
                            foregroundColor: Colors.white),
                      ),

                      SizedBox(height: 22,),

                      Row(
          children: [
            Expanded(
              child: Divider(
                color: Colors.grey,
                thickness: 3,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('Login with', style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold,color: Colors.grey.shade700)),
            ),
            Expanded(
              child: Divider(
                color: Colors.grey,
                thickness: 3,
              ),
            ),
          ],
        ),
        SizedBox(height: 22,),

                      Row(
                        
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        
                        children: [
                          SizedBox(height: 40,width: 40,child: Image.asset("assets/logo/facebook.png"),),
                          SizedBox(height: 40,width: 40,child: Image.asset("assets/logo/twitter.png"),),
                          SizedBox(height: 40,width: 40,child: Image.asset("assets/logo/google.png"),),
                          
                          SizedBox(height: 40,width: 40,child: Image.asset("assets/logo/apple.png"),)
                          
                        ],
                      ),

                      SizedBox(height: 22,),

                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "New User? ",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(context,MaterialPageRoute(builder: (context) => SignupScreen()));
                                },
                                child: Text(
                                  "Create an account",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade600),
                                ))
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
