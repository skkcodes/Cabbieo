

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:waygo/screens/auth/login_screen.dart';
import 'package:waygo/screens/auth/signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Image.asset(
          "assets/logo/welcome2.png",
          fit: BoxFit.cover,
          height: double.infinity,
          width: double.infinity,
        ),
        Container(
          height: 400,
          width: double.infinity,
          color: Colors.white,
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              SizedBox(
                height: 70,
              ),
              Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: 300,
                    width: 300,
                    child: Image.asset(
                      "assets/logo/icon.png",
                      fit: BoxFit.cover,
                    ),
                  )),
              SizedBox(
                height: 100,
              ),
              Center(
                child: Text(
                  '" Wherever you go,\n WayGo gets you there.\n Let’s ride! "',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 0, 21, 101)),
                ),
              ),
              SizedBox(
                height: 20,
              ),
              
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
          padding: const EdgeInsets.all(20.0),
          child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ElevatedButton(
                    
                      onPressed: () {
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SignupScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                          elevation: 10,
                          backgroundColor: const Color.fromARGB(255, 0, 31, 118),
                          foregroundColor:
                              const Color.fromARGB(255, 255, 255, 255)),
                      child: Text(
                        "Signup",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      )),
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 30.0,bottom: 30),
          child: Align(
                  alignment: Alignment.bottomRight,
                  child: GestureDetector(
                    
                      onTap: () {
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => LoginScreen()));
                      },
                      
                      child: Text(
                        "Login",
                        style: TextStyle(fontWeight: FontWeight.bold,fontSize: 22,color: const Color.fromARGB(255, 2, 51, 91)),
                      )),
                ),
        )
          ],
        )
        
      ]),
    );
  }
}



class WelcomePage extends StatefulWidget {
  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  // List of image paths
  final List<String> images = [
    
    'assets/logo/icon.png',
    'assets/logo/2.png',
    'assets/logo/3.png',
  ];
  final List<String> svgs = [
    "assets/logo/blob3.svg",
    "assets/logo/blob2.svg",
    "assets/logo/blob3.svg",
    
  ];
  final List<String> quotes = [
    "Seamless rides, endless destinations,\n your comfort matters.",
    "Safe, swift rides to your next adventure.",
    "Let us take you places with ease and comfort.",
    
  ];
  final List<String> titles = [
    "Travel Made Easy",
    "Explore With Us",
    "Ride, Relax, Repeat",
    
  ];

  // Controller for the PageView
  final PageController _pageController = PageController();

  // Function to handle image change on page scroll
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // PageView for displaying one image at a time
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: images.length,  // Number of items
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    // Display SVG if it's an SVG index
                    SvgPicture.asset(
                      svgs[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    // Display image if it's an image index
                    Center(
                      child: Image.asset(
                        images[index],
                        fit: BoxFit.scaleDown,
                        width: 300, // Adjust size based on your requirements
                        height: 300,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(titles[_currentIndex],style: TextStyle(fontWeight: FontWeight.bold,fontSize: 22),),
              ],
            ),
          ),
          SizedBox(height: 10,),
          Text(quotes[_currentIndex],style: TextStyle(fontWeight: FontWeight.bold,fontSize: 15,color: Colors.grey),),
          
          SizedBox(height: 30),

          // Dots Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                child: _currentIndex == index
                    ? Text('-', style: TextStyle(fontSize: 30, color: Colors.amber)) // Active dot shows "-"
                    : Text('.', style: TextStyle(fontSize: 30, color: Colors.amber)), // Inactive dots show "."
              );
            }),
          ),

          SizedBox(height: 20),

          

          // Next Button
          ElevatedButton(
            onPressed: () {
              // Move to the next page (image)
              if (_currentIndex < images.length - 1) {
                _pageController.nextPage(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              } else {
                // Optionally, restart from the first image
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>WelcomeScreen()));
              }
            },
            child: Text("Next",style: TextStyle(fontWeight: FontWeight.bold),),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow.shade700,
              foregroundColor: Colors.white
            ),
          ),
          SizedBox(height: 10,)
          
        ],
      ),
    );
  }
}