import 'package:flutter/material.dart';
import 'package:livemeet/widgets/Button.dart';
import 'package:livemeet/widgets/CustomText.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:supabase_flutter/supabase_flutter.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  String step = 'Step 1 of 2';
  bool isUploaded = false;
  String fileName = '';
  bool isError = false;
  String errorText = '';
  String summary = '';
  List<Map<String, dynamic>> rows = [];

  String cellText(Data? cell) {
    final v = cell?.value;
    if (v == null) return '';
    return v.toString().trim();
  }

  // cell ki date -> '2026-10-13'
  String? cellDate(Data? cell) {
    final v = cell?.value;
    if (v is DateCellValue) {
      return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
    }
    if (v is DateTimeCellValue) {
      return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
    }
    return null;
  }

  // cell ka time -> '11:00'
  String? cellTime(Data? cell) {
    final v = cell?.value;
    if (v is TimeCellValue) {
      return '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
    }
    if (v is DateTimeCellValue) {
      return '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
    }
    return null;
  }

  Future<void> pickFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      // user ne cancel kar diya
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first]!;

      final list = <Map<String, dynamic>>[];


      int groupNo = 0;
      String lastRow = '';
      String lastDate = '';

      for (final row in sheet.rows) {
        if (row.length < 8) continue;

        final date = cellDate(row[7]);
        final time = cellTime(row[6]);

        if (date == null || time == null) continue;
        final key = '$date|$time|${cellText(row[4])}|${cellText(row[3])}';

        if (date != lastDate) {
          groupNo = 0;
          lastDate = date;
        }
        
        if (key != lastRow) {
          groupNo++;
          lastRow = key;
        }

    list.add({
      'group_no': groupNo,
      'meeting_date': date,
      'meeting_time': time,
      'project': cellText(row[4]),
      'supervisor': cellText(row[3]),
      'reg_no': cellText(row[1]),
      'student_name': cellText(row[2]),
      'tech': cellText(row[5]),
    });


      }
      if (list.isEmpty) {
        setState(() {
          isError = true;
          errorText = 'Is file mein koi valid row nahi mili';
        });
        return;
      }

      // Days / groups / students ginti
      final days = list.map((r) => r['date']).toSet().length;
      final groups = list
          .map((r) => '${r['date']}|${r['time']}|${r['project']}|${r['supervisor']}')
          .toSet()
          .length;

      // Debug Console mein check ke liye (baad mein hata dena)
      for (final r in list.take(3)) {
        print(r);
      }
      print('Total students: ${list.length}');

      setState(() {
        rows = list;
        fileName = file.name;
        summary = '$days days | $groups groups | ${list.length} students';
        isUploaded = true;
        isError = false;
        step = 'Step 2 of 2';
      });
    } catch (e) {
      print('Error: $e');
      setState(() {
        isError = true;
        errorText = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(18, 60, 18, 18),
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(text: step),
                CustomText(text: 'Import schedule', fontSize: 38, fontWeight: FontWeight.w900),

                SizedBox(height: 10),

                GestureDetector(
                  onTap: pickFile,
                  child: AnimatedContainer(
                    width: double.infinity,
                    padding: EdgeInsets.all(48),
                    duration: Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Column(
                        children: [
                          isUploaded
                              ? Column(
                                  children: [
                                    CustomText(text: fileName, fontSize: 24, fontWeight: FontWeight.bold),
                                    CustomText(text: summary),
                                    CustomText(text: 'Tap to choose another Excel file'),
                                  ],
                                )
                              : CustomText(text: 'Tap to upload Excel file'),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 10),

                isError
                    ? AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        child: CustomText(text: errorText, color: Colors.red),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 223, 221),
                          borderRadius: BorderRadius.circular(25),
                        ),
                      )
                    : SizedBox(),
            SizedBox(height: 10),
                Button(
                  enabled: isUploaded,
                  text: 'Confirm import',
                  onTap: ()async{
                        if (!isUploaded || isError) {
                          return;
                        }

                        try{
                          await Supabase.instance.client.from('meeting_schedule' ).insert(rows);
                          print('Inserted: ${rows.length}');
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Data imported succeffluuy')));
                          setState(() {
                            isUploaded=false;
                          });
                        }
                        catch(e){
                          setState(() {
                             isError = true;
                             errorText = 'Import error: $e';
                          });
                          print(e.toString());

                        }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}