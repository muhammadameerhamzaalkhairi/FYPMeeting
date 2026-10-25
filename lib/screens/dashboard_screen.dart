import 'package:flutter/material.dart';
import 'package:livemeet/widgets/Button.dart';
import 'package:livemeet/widgets/CustomText.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String formateDate(){
    final DateTime now=DateTime.now();
    final String weekday=days[now.weekday-1];
    final int day =now.day;
    final String month=months[now.month-1];
    return '${weekday}, ${day} ${month}';
  }

  bool isLoading = true;
  bool isMeeting = false;
  bool isError = false;

  @override
  void initState() {
    super.initState();
    checkMeeting();
  }


  Future<void> checkMeeting() async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
        final rows = await Supabase.instance.client.from('meeting').select('mid').eq('meeting_date', today).limit(1);
    } catch (e) {
      
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 60, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomText(text: formateDate()),
              CustomText(text: 'Meeting is Live', fontSize: 38,fontWeight: FontWeight.w900,),
              SizedBox(height: 10,),
              Container(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(
                        text: 'Now running', 
                        fontWeight: FontWeight.w600,
                      ),
                      SizedBox(height: 5,),
                      //////////////////////
                      ///project name
                      CustomText(
                        text: 'Director Dashboard for paper setting', 
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                        height: 1,
                      ),
                      SizedBox(height: 10,),
                      CustomText(text: 'Amir - Started 11:00 - 14min elapsed',),
                      SizedBox(height: 15,),
                      Container(
                        width: 130,
                        height: 50,
                        child: Button(text: 'Open Live'),
                      )
                    ],
                  ),
                ),
                decoration: BoxDecoration(
                  color:  const Color(0xFFDDF35C),
                  borderRadius: BorderRadius.circular(25)
                ),
              ),
              SizedBox(height: 10,),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(12),
                      height: 90,
                      decoration: BoxDecoration(
                        color:  const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(25)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomText(height: 1,text: '2', fontSize: 42,fontWeight: FontWeight.w900,),

                          CustomText(text: 'Done'),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10,),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(12),
                      height: 90,
                      decoration: BoxDecoration(
                        color:  const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(25)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomText(height: 1,text: '5', fontSize: 42,fontWeight: FontWeight.w900,),

                          CustomText(text: 'Remaining'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // SizedBox(height: 10,),
              // Button(text: 'Start Meting'),
              SizedBox(height: 10,),
              Button(text: 'End Meeting')
            ],
          ),
        ),
      ),
    );
  }
}