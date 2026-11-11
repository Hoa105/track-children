import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../app_layout.dart';
import '../../models/progress_review.dart';
import 'progress_review_view.dart';

const _heading = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
);

/// Ngày quay video đầu / cuối của một lần đánh giá.
typedef ReviewPeriod = (DateTime, DateTime) Function(ProgressReview review);

/// Every progress review of the child, newest first; tap opens the detail.
class ReviewHistoryScreen extends StatelessWidget {
  const ReviewHistoryScreen({
    super.key,
    required this.reviews,
    required this.period,
  });
  final List<ProgressReview> reviews;
  final ReviewPeriod period;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: Text('Lịch sử đánh giá (${reviews.length})', style: _heading),
    ),
    body: ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.pagePadding,
        8,
        AppLayout.pagePadding,
        32,
      ),
      itemCount: reviews.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final review = reviews[i];
        return ProgressReviewTile(
          review: review,
          period: period(review),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  ReviewDetailScreen(review: review, period: period(review)),
            ),
          ),
        );
      },
    ),
  );
}

/// Full result of one progress review.
class ReviewDetailScreen extends StatelessWidget {
  const ReviewDetailScreen({
    super.key,
    required this.review,
    required this.period,
  });
  final ProgressReview review;
  final (DateTime, DateTime) period;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: Text(
        'Đánh giá ngày ${dateLabel(review.createdAt)}',
        style: _heading,
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.pagePadding,
        8,
        AppLayout.pagePadding,
        32,
      ),
      children: [ProgressReviewView(review: review, period: period)],
    ),
  );
}
