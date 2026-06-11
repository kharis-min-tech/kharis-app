/// Static content for the Your Journey stepper screen.
/// All 4 steps are defined here as const data; no network required.
library;

class JourneyStep {
  const JourneyStep({
    required this.title,
    required this.subtitle,
    required this.scripture,
    required this.scriptureRef,
    required this.body,
    required this.actionLabel,
  });

  final String title;
  final String subtitle;
  final String scripture;
  final String scriptureRef;
  final String body;
  final String actionLabel;
}

const List<JourneyStep> kJourneySteps = [
  JourneyStep(
    title: 'Salvation',
    subtitle: 'Receiving New Life',
    scripture:
        '"If you declare with your mouth, Jesus is Lord, and believe in your heart that God raised him from the dead, you will be saved."',
    scriptureRef: 'Romans 10:9',
    body:
        'Salvation begins the moment you turn to Jesus and place your trust in him. It is not about being good enough or having everything figured out. God meets you exactly where you are, and through Christ, every past thing is forgiven and a completely new life begins. If you have made that decision, you are now part of the family of God.',
    actionLabel: 'Mark complete',
  ),
  JourneyStep(
    title: 'Baptism',
    subtitle: 'Going Public with Your Faith',
    scripture:
        '"Therefore go and make disciples of all nations, baptising them in the name of the Father and of the Son and of the Holy Spirit."',
    scriptureRef: 'Matthew 28:19',
    body:
        'Water baptism is your first public declaration that your old life is buried and you have been raised to walk in the new one. It is an act of obedience and a bold statement to those around you that Jesus is Lord. If you have given your life to Christ and have not yet been baptised, speak to a team member on Sunday and we will make it happen.',
    actionLabel: 'Mark complete',
  ),
  JourneyStep(
    title: 'Holy Spirit',
    subtitle: 'Living with Power',
    scripture:
        '"But you will receive power when the Holy Spirit comes on you; and you will be my witnesses in Jerusalem, and in all Judea and Samaria, and to the ends of the earth."',
    scriptureRef: 'Acts 1:8',
    body:
        'The Holy Spirit is not a one-time encounter; he is God living inside you, equipping you for daily life. He gives you strength to walk through difficulty, wisdom to make decisions, and gifts to serve others well. Learning to be sensitive to his voice and to depend on his leading is one of the greatest privileges of the Christian life.',
    actionLabel: 'Mark complete',
  ),
  JourneyStep(
    title: 'Next Steps',
    subtitle: 'Planted and Growing',
    scripture:
        '"And let us not give up meeting together, as some are in the habit of doing, but encouraging one another, and all the more as you see the Day approaching."',
    scriptureRef: 'Hebrews 10:25',
    body:
        'Faith grows fastest in community. Joining a K-Group connects you to a smaller circle of people who will do life with you through the week, while finding a place to serve puts your gifts to work for something bigger than yourself. Both are available to you right now. Ask any team member on Sunday to help you take the next step.',
    actionLabel: 'Mark complete',
  ),
];
