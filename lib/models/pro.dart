import 'package:flutter/material.dart';

/// Mirrors a single entry in the PROS map from customer.html
class Pro {
  final String id;
  final String initials;
  final List<Color> gradient;
  final String name;
  final String? tier; // e.g. 'Gold' or null
  final String role;
  final String rating;
  final int reviews;
  final String responds;
  final String verifiedSince;
  final String price;
  final String match; // short one-line match summary shown in pro card
  final String about;
  final List<String> services;
  final List<List<String>> faqs; // [question, answer]
  final List<ProReview> revs;

  const Pro({
    required this.id,
    required this.initials,
    required this.gradient,
    required this.name,
    required this.tier,
    required this.role,
    required this.rating,
    required this.reviews,
    required this.responds,
    required this.verifiedSince,
    required this.price,
    required this.match,
    required this.about,
    required this.services,
    required this.faqs,
    required this.revs,
  });
}

class ProReview {
  final String initials;
  final String name;
  final String rating;
  final String text;
  const ProReview(this.initials, this.name, this.rating, this.text);
}

class Booking {
  final String proId;
  final String slot;
  const Booking({required this.proId, required this.slot});
}
