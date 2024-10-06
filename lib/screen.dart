import 'package:avatar_better/avatar_better.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:local_notification/confrim_button.dart';
import 'package:local_notification/datetimepicker.dart';
import 'package:local_notification/notification/notification_service.dart';
import 'package:shamsi_date/shamsi_date.dart';

class Screen extends StatefulWidget {
  const Screen({super.key});

  @override
  State<Screen> createState() => _ScreenState();
}

class _ScreenState extends State<Screen> {
  NotificationService notificationService = NotificationService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  Jalali? _selectedDateTime;
  TimeOfDay? _selectedTimeOfDay;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  String _convertToEnglishNumbers(String input) {
    const persianNumbers = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const englishNumbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    for (int i = 0; i < persianNumbers.length; i++) {
      input = input.replaceAll(persianNumbers[i], englishNumbers[i]);
    }

    return input;
  }

  void _scheduleNotification(BuildContext context) {
    String title = _titleController.text;
    String body = _bodyController.text;
    String dateTimeText = _timeController.text.trim(); // حذف فاصله‌های اضافی

    // تبدیل اعداد فارسی به انگلیسی
    dateTimeText = _convertToEnglishNumbers(dateTimeText);

    if (dateTimeText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time')),
      );
      return;
    }

    if (title.isEmpty || body.isEmpty || dateTimeText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    // اعتبارسنجی فرمت ورودی با regex
    RegExp regex = RegExp(r'^\d{4}/\d{2}/\d{2} \d{2}:\d{2} (AM|PM)$');
    if (!regex.hasMatch(dateTimeText)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid date format. Use yyyy/mm/dd HH:mm AM/PM'),
        ),
      );
      return;
    }

    try {
      // Parse date and time after validation
      List<String> parts = dateTimeText.split(' ');
      List<String> dateParts = parts[0].split('/');
      List<String> timeParts = parts[1].split(':');
      String period = parts[2];

      // Convert Jalali to Gregorian
      Jalali jalaliDate = Jalali(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );

      Gregorian gregorianDate = jalaliDate.toGregorian();

      int hour = int.parse(timeParts[0]);
      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }

      // Combine Gregorian date with the converted time
      DateTime combinedDateTime = DateTime(
        gregorianDate.year,
        gregorianDate.month,
        gregorianDate.day,
        hour,
        int.parse(timeParts[1]),
      );

      DateTime now = DateTime.now();

      if (combinedDateTime.isBefore(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time must be in the future')),
        );
        return;
      }

      notificationService.scheduleNotification(
        id: 1,
        title: title,
        body: body,
        scheduledDate: combinedDateTime,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification scheduled for ${DateFormat('yyyy-MM-dd HH:mm').format(combinedDateTime)}'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid date format or conversion error.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Schedule Notification'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // فیلد ورودی برای عنوان
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // فیلد ورودی برای متن
              TextField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Body',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // PersianDatePicker برای انتخاب تاریخ و زمان
              PersianDatePicker(
                confrimButtonConfig: ConfirmButtonConfig(),
                firstDate: Jalali.now(),
                onChanged: (dateTime, timeOfDay) {
                  _selectedDateTime = dateTime;
                  _selectedTimeOfDay = timeOfDay;
                  _timeController.text = '${dateTime.formatFullDate()} ${timeOfDay.format(context)}';
                },
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () => _scheduleNotification(context),
                child: const Text('Schedule Notification'),
              ),
              const SizedBox(height: 10),
              Avatar(
                text: 'Flutter',
                showPageViewOnTap: true,
              )
            ],
          ),
        ),
      ),
    );
  }
}
