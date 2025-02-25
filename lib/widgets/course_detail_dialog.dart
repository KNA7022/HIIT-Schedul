import 'package:flutter/material.dart';
import '../models/course_model.dart';

class CourseDetailDialog extends StatelessWidget {
  final CourseInfo course;

  const CourseDetailDialog({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '课程详情',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildDetailItem(context, '课程名称：', course.courseName),
            _buildDetailItem(context, '授课教师：', course.teacherName),
            _buildDetailItem(context, '教学地点：', '${course.school} ${course.room}'),
            _buildDetailItem(context, '上课时间：', '${course.xq} ${course.jie}'),
            _buildDetailItem(context, '课程时间：', course.time),
            _buildDetailItem(context, '周次：', course.week),
            if (course.cursProperty.isNotEmpty)
              _buildDetailItem(context, '考核方式：', course.cursProperty),
            if (course.cursForm.isNotEmpty)
              _buildDetailItem(context, '考试形式：', course.cursForm),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
