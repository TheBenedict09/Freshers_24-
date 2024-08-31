// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:fresher_scanner_2024/exceptions.dart';
import 'package:lottie/lottie.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: AnimatedSplashScreen(
        duration: 3000,
        splash: Image.asset("assets/images/ABS.gif"),
        nextScreen: const HomePage(),
        splashTransition: SplashTransition.fadeTransition,
        backgroundColor: Color(0xff202020),
        splashIconSize: MediaQuery.sizeOf(context).height * 0.5,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String result = '';
  bool _isLoading = false;

  Future<void> checkRegistrationNumber(String regNumber) async {
    if (!mounted) return; // Ensure widget is still mounted

    setState(() {
      result = regNumber;
      _isLoading = true;
    });

    if (exceptionList.containsKey(result)) {
      await showCustomDialog(
        exceptionList[result]!,
        'assets/animations/Verified.json',
        Colors.green,
      );
      setState(() {
        _isLoading = false;
      });
      return;
    } else if (result.length == 9 && result.startsWith('2024')) {
      final firestore = FirebaseFirestore.instance;

      try {
        await Future.microtask(() async {
          final docSnapshot =
              await firestore.collection('details').doc(result).get();
          bool isVerified = docSnapshot.exists;

          if (isVerified) {
            int numberOfEntries = docSnapshot.data()?['number_of_entries'] ?? 0;

            if (numberOfEntries >= 1) {
              await showCustomDialog(
                "Already Checked In",
                'assets/animations/Notverified.json',
                Colors.red,
              );
            } else {
              await firestore.collection('details').doc(result).update({
                'number_of_entries': FieldValue.increment(1),
                'time_of_entry': FieldValue.serverTimestamp(),
              });

              await showCustomDialog(
                docSnapshot['name'],
                'assets/animations/Verified.json',
                Colors.green,
              );
            }
          } else {
            await showCustomDialog(
              "Not Verified",
              'assets/animations/Notverified.json',
              Colors.red,
            );
          }
        });
      }
      // Your Firestore operation here
      on SocketException catch (_) {
        // Handle no internet connection
        if (mounted) {
          showSnackbar("No internet connection. Please check your connection.");
        }
      } on FirebaseException catch (e) {
        // Handle Firebase-specific exceptions
        if (e.code == 'network-request-failed') {
          if (mounted) {
            showSnackbar("Network request failed. No internet connection.");
          }
        } else {
          if (mounted) {
            showSnackbar("Firebase error occurred: ${e.message}");
          }
        }
      } catch (e) {
        // Handle any other generic exceptions
        if (mounted) {
          showSnackbar("Error Occurred: $e");
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else if (result == "-1") {
      await showCustomDialog(
        "No Code Scanned",
        'assets/animations/Notverified.json',
        Colors.red,
      );
    } else {
      await showCustomDialog(
        "Invalid Reg Number",
        'assets/animations/Notverified.json',
        Colors.red,
      );
    }
  }

  Future<void> resetNumberOfEntries() async {
    final firestore = FirebaseFirestore.instance;

    try {
      final querySnapshot = await firestore.collection('details').get();
      // Loop through each document and update 'number_of_entries' to 0
      for (var doc in querySnapshot.docs) {
        await doc.reference.update({'number_of_entries': 0});
      }

      // Optionally, show a confirmation message to the user
      if (mounted) {
        showSnackbar("Number of entries reset for all records.");
      }
    } on FirebaseException catch (e) {
      // Handle Firebase-specific exceptions
      if (mounted) {
        showSnackbar("Firebase error occurred: ${e.message}");
      }
    } catch (e) {
      // Handle any other generic exceptions
      if (mounted) {
        showSnackbar("Error Occurred: $e");
      }
    }
  }

  Future<void> showCustomDialog(
      String message, String animationFile, Color barrierColor) async {
    return showDialog(
      barrierDismissible: false,
      barrierColor: barrierColor,
      context: context,
      builder: (context) {
        Timer(
          const Duration(seconds: 5),
          () {
            if (mounted) {
              // Navigator.of(context).pop(true);
            }
          },
        );

        return AlertDialog(
          elevation: 0,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                animationFile,
                width: MediaQuery.of(context).size.width * 0.6,
                repeat: false,
                animate: true,
              ),
              Text(
                result,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "LimeLight",
                  fontSize: MediaQuery.of(context).size.width * 0.1,
                  color: const Color(0xffFFFFE0),
                ),
              ),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "LimeLight",
                  fontWeight: FontWeight.w800,
                  fontSize: MediaQuery.of(context).size.width * 0.1,
                  color: const Color(0xffFFFFE0),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
        );
      },
    );
  }

  void showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        child: const Icon(Icons.warning),
        onPressed: () async {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                actionsAlignment: MainAxisAlignment.center,
                content: SizedBox(
                  width: MediaQuery.sizeOf(context).width * 0.8,
                  height: MediaQuery.sizeOf(context).height * 0.8,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Warning: RESET",
                        style: TextStyle(
                            fontFamily: "Limelight",
                            fontWeight: FontWeight.bold,
                            fontSize: 50),
                      ),
                      FloatingActionButton.large(
                        backgroundColor: Colors.red,
                        child: const Text("Reset"),
                        onPressed: () async {
                          await resetNumberOfEntries();
                        },
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      body: Stack(children: [
        SizedBox(
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height,
          child: Image.asset(
            'assets/images/FreshersBG.png',
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height,
          // decoration: const BoxDecoration(
          //   gradient: LinearGradient(
          //     colors: [
          //       Color(0xFFF21FB9), // Pink shade
          //       Color(0xFFF16CAF), // Light Pink shade
          //       Color(0xFFE91E63), // Additional similar pink shade
          //       Color(0xFF2A27D8), // Blue shade
          //       Color(0xFF3B2EAF), // Additional similar blue shade
          //       Color(0xFF551C73), // Purple shade
          //     ],
          //     begin: Alignment.topLeft,
          //     end: Alignment.bottomRight,
          //     stops: [0.1, 0.3, 0.5, 0.7, 0.8, 1.0],
          //   ),
          // ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.1,
                ),
                Image.asset(
                  'assets/images/image.png',
                  width: MediaQuery.sizeOf(context).width * 0.8,
                ),
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.03,
                ),
                Column(
                  children: [
                    Text(
                      "freshers 24'",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontFamily: "LimeLight",
                        fontSize: MediaQuery.sizeOf(context).width * 0.15,
                        color: const Color(0xffFFFFE0),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(
                          right: MediaQuery.sizeOf(context).width * 0.1),
                      alignment: Alignment.topRight,
                      child: Text(
                        "euphoria",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w300,
                          fontFamily: "LimeLight",
                          fontSize: MediaQuery.sizeOf(context).width * 0.11,
                          color: const Color(0xffFFFFE0),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.08,
                ),
                Container(
                  width: MediaQuery.sizeOf(context).width * 0.6,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () async {
                      var res = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const SimpleBarcodeScannerPage(),
                        ),
                      );

                      if (res == null || res.isEmpty) {
                        showSnackbar("Nothing scanned");
                      } else {
                        setState(() {
                          result = res;
                        });
                        await Future.microtask(() {
                          checkRegistrationNumber(result);
                        });
                      }
                    },
                    child: Lottie.asset(
                      'assets/animations/Scanner.json',
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),
                Padding(
                  padding: EdgeInsets.only(
                      left: MediaQuery.sizeOf(context).width * 0.3,
                      right: MediaQuery.sizeOf(context).width * 0.3),
                  child: const Divider(),
                ),
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStatePropertyAll(
                      Colors.white.withOpacity(0.5),
                    ),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        String manualInput = '';
                        return AlertDialog(
                          title: const Text("Enter Registration Number"),
                          content: TextField(
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              manualInput = value;
                            },
                            decoration: const InputDecoration(
                              hintText: "Enter Reg Number",
                            ),
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                if (manualInput.isNotEmpty) {
                                  Future.microtask(() {
                                    checkRegistrationNumber(manualInput);
                                  });
                                }
                              },
                              child: const Text("Verify"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Enter Reg Number",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontFamily: "LimeLight",
                        fontSize: MediaQuery.sizeOf(context).width * 0.05,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
