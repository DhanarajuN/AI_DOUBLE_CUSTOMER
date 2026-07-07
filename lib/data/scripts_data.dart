import 'package:flutter/material.dart';
import '../models/convo.dart';

/// Direct port of the `SCRIPTS` object: the guided AI-intake conversation
/// for each category.
final Map<String, CategoryScript> kScripts = {
  'insurance': const CategoryScript(
    categoryLabel: 'Insurance',
    greet: "Hi! I'm your AI Double assistant. I can help you find the right insurance advisor. What kind of cover are you looking for?",
    steps: [
      ScriptStep(
        chips: ['Home insurance', 'Term life', 'Health cover', 'Motor'],
        ask: 'Got it. And roughly where are you located, so I can find advisors near you?',
      ),
      ScriptStep(
        chips: ['Jubilee Hills', 'Banjara Hills', 'Gachibowli', 'Somewhere else'],
        ask: 'Thanks. How soon do you need this sorted?',
      ),
      ScriptStep(
        chips: ['Urgent — this week', 'This month', 'Just exploring'],
        ask: null,
      ),
    ],
    reveal: "Perfect — I've matched you with 2 verified insurance advisors near you, ranked by rating and response time:",
    proIds: ['meera', 'kapoor'],
    after: ['Compare their cover', 'Get a quote'],
  ),
  'education': const CategoryScript(
    categoryLabel: 'Education',
    greet: "Hi! I'm your AI Double assistant. Let's find you the right tutor. Which subject and grade?",
    steps: [
      ScriptStep(
        chips: ['Grade 10 Physics', 'Grade 12 Maths', 'Science', 'Other'],
        ask: 'Great. Any preference on medium of instruction?',
      ),
      ScriptStep(
        chips: ['English medium', 'Telugu medium', 'Either'],
        ask: 'And do you prefer online, in-person, or a coaching centre?',
      ),
      ScriptStep(
        chips: ['Online', 'In-person', 'Coaching centre'],
        ask: null,
      ),
    ],
    reveal: 'Here are 2 tutors that fit — both have demo slots open this week:',
    proIds: ['ramesh', 'sri'],
    after: ['See syllabus fit', 'Book a free demo'],
  ),
  'home': const CategoryScript(
    categoryLabel: 'Home Services',
    greet: "Hi! I'm your AI Double assistant. What do you need help with at home?",
    steps: [
      ScriptStep(
        chips: ['Electrical', 'Plumbing', 'Appliance repair', 'Other'],
        ask: 'Understood. Is this urgent or can it be scheduled?',
      ),
      ScriptStep(
        chips: ['Urgent — today', 'Tomorrow', 'This week'],
        ask: 'What area are you in, so I can find someone close by?',
      ),
      ScriptStep(
        chips: ['Jubilee Hills', 'Kondapur', 'Madhapur', 'Other'],
        ask: null,
      ),
    ],
    reveal: 'I found 2 verified professionals available near you:',
    proIds: ['suresh', 'quick'],
    after: ['Describe the issue', 'Call now'],
  ),
  'health': const CategoryScript(
    categoryLabel: 'Healthcare',
    greet: "Hi! I'm your AI Double assistant. What kind of care are you looking for?",
    steps: [
      ScriptStep(
        chips: ['Physiotherapy', 'Back/neck pain', 'Sports rehab', 'Other'],
        ask: 'Got it. Would you prefer home visits or an in-clinic visit?',
      ),
      ScriptStep(
        chips: ['Home visit', 'In-clinic', 'Either'],
        ask: 'And your area, so I can find someone nearby?',
      ),
      ScriptStep(
        chips: ['Kondapur', 'Gachibowli', 'Madhapur', 'Other'],
        ask: null,
      ),
    ],
    reveal: 'Here are 2 verified physiotherapists near you:',
    proIds: ['nisha', 'active'],
    after: ['Describe symptoms', 'Home visit slots'],
  ),
};

/// Direct port of CATMETA: shown in the "New request" category picker sheet.
final Map<String, CategoryMeta> kCategoryMeta = {
  'insurance': CategoryMeta(
    Icons.shield_outlined,
    [const Color(0xFFF43F5E), const Color(0xFFBE123C)],
    'Insurance',
    'Advisors, brokers, claims',
  ),
  'education': CategoryMeta(
    Icons.school_outlined,
    [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
    'Education',
    'Tutors & coaching',
  ),
  'home': CategoryMeta(
    Icons.build_outlined,
    [const Color(0xFFEF4444), const Color(0xFFDC2626)],
    'Home Services',
    'Electrician, plumber, repairs',
  ),
  'health': CategoryMeta(
    Icons.favorite_border,
    [const Color(0xFF10B981), const Color(0xFF047857)],
    'Healthcare',
    'Doctors, physios, clinics',
  ),
};

/// Available booking time slots (mirrors the SLOTS array).
const List<String> kSlots = [
  'Today 4:00',
  'Today 5:30',
  'Tue 10:00',
  'Tue 2:00',
  'Fri 11:00',
  'Fri 4:30',
];
