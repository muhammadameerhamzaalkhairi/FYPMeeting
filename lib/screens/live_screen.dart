import 'package:flutter/material.dart';
import 'package:livemeet/widgets/CustomText.dart';
import 'package:livemeet/widgets/LiveDetailMeetingCard.dart';
import 'package:livemeet/widgets/TextBox.dart';
import 'package:livemeet/widgets/filter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final List<String> days = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  final List<String> months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final TextEditingController search = TextEditingController();

  final List<String> filters = ['Add', 'Running', 'Upcomming', 'Done'];

  bool isAdd = true;
  bool isRun = false;
  bool isUp = false;
  bool isDone = false;

  int? selectedCard;

  String formateDate() {
    final DateTime now = DateTime.now();
    final String weekday = days[now.weekday - 1];
    final int day = now.day;
    final String month = months[now.month - 1];

    return '$weekday, $day $month';
  }

  List<Map<String, dynamic>> meetings = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 60, 18, 18),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomText(text: formateDate()),
              CustomText(
                text: 'Live',
                fontSize: 38,
                fontWeight: FontWeight.w900,
              ),
              const SizedBox(height: 10),

              TextBox(
                controller: search,
                hintText: 'Search',
              ),
              const SizedBox(height: 10),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 10,
                  children: [
                    Filter(
                      text: filters[0],
                      onTap: () {
                        setState(() {
                          isAdd = true;
                          isRun = false;
                          isUp = false;
                          isDone = false;
                        });
                      },
                      isSelected: isAdd,
                    ),
                    Filter(
                      text: filters[1],
                      onTap: () {
                        setState(() {
                          isAdd = false;
                          isRun = true;
                          isUp = false;
                          isDone = false;
                        });
                      },
                      isSelected: isRun,
                    ),
                    Filter(
                      text: filters[2],
                      onTap: () {
                        setState(() {
                          isAdd = false;
                          isRun = false;
                          isUp = true;
                          isDone = false;
                        });
                      },
                      isSelected: isUp,
                    ),
                    Filter(
                      text: filters[3],
                      onTap: () {
                        setState(() {
                          isAdd = false;
                          isRun = false;
                          isUp = false;
                          isDone = true;
                        });
                      },
                      isSelected: isDone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              Livedetailmeetingcard(
                title: 'Director Dashboard for paper setting',
                time: '11:00 AM',
                isExpanded: false,
                isSelected: selectedCard == 1,
                number: 1,
                onExpand: () {},
                onTap: () {
                  setState(() {
                    selectedCard = 1;
                  });
                },
                status: 'Done',
                supervisor: 'Amir',
              ),

              Livedetailmeetingcard(
                title: 'Smart App',
                time: '11:15 AM',
                isExpanded: false,
                isSelected: selectedCard == 2,
                number: 2,
                onExpand: () {},
                onTap: () {
                  setState(() {
                    selectedCard = 2;
                  });
                },
                status: 'Running',
                supervisor: 'Saeed',
              ),
            ],
          ),
        ),
      ),
    );
  }
}