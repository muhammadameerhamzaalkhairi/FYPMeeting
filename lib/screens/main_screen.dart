import 'package:flutter/material.dart';
import 'package:livemeet/screens/dashboard_screen.dart';
import 'package:livemeet/screens/import_screen.dart';
import 'package:livemeet/screens/live_screen.dart';
import 'package:livemeet/widgets/Button.dart';
import 'package:livemeet/widgets/CustomText.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

 bool isHome=true;
 bool isLive=false;
 bool isImport=false;
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isHome ? DashboardScreen() : isImport ? ImportScreen() : LiveScreen(),
      bottomNavigationBar: AnimatedContainer(
        
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(12),
        margin: EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: Colors.black,
        ),
        width: double.infinity,
        child: Row(
          spacing: 15,
          children: [

            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    isHome=true;
                    isImport=false;
                    isLive=false;
                  });
                },
                child: Button(text: 'Home', color: isHome ? const Color(0xFFDDF35C):Colors.white, foreColor: isHome ? Colors.black : Colors.white,),
              )
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    isHome=false;
                    isImport=true;
                    isLive=false;
                  });
                },
                child: Button(text: 'Import', color: isImport ? const Color(0xFFDDF35C):Colors.white, foreColor: isImport ? Colors.black : Colors.white,),
              )
            ),

            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    isHome=false;
                    isImport=false;
                    isLive=true;
                  });
                },
                child: Button(text: 'Live', color: isLive ? const Color(0xFFDDF35C):Colors.white, foreColor: isLive ? Colors.black : Colors.white,),
              )
            ),


            
          ],
        ),
      )
    );
  }
}