import 'package:flutter/material.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: color.scaffoldBackgroundColor,
      child: ListView(
        children: [
          Text(
            "The Twelve Apostles Church In Christ",
            style: color.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle("Historical Milestones"),
          _bullet("1832 - First Apostle J.B. Cardale"),
          _bullet("1835 - Catholic Apostolic Church founded"),
          _bullet("1852 - C.G. Klibbe was born in December"),
          _bullet("1889 - Carl Georg Klibbe sent to SA by Apostle Niemeyer"),
          _bullet("1892 - C.G. Klibbe appointed Apostle in Europe"),
          _bullet("1893 - First sealing in Cape Town (New Apostolic Church)"),
          _bullet("1913 - Doctrinal split with Chief Apostle Niehaus"),
          _bullet("1926 - Legal recognition of Old Apostolic Church"),
          _bullet("1931 - Apostle Klibbe dies, son-in-law H. Velde dies 1956"),
          _bullet("1953 - First black Apostle Hlatshwayo ordained"),
          _bullet("1972 - Apostle S.D. Phakathi ordained"),
          _bullet("1978 - Church officially registered as TACC"),
          const SizedBox(height: 16),
          _sectionTitle("Divine Foundation"),
          _paragraph(
            "Jesus Christ chose twelve Apostles to continue his ministry. Their mission, supported by the Holy Spirit, was to carry divine authority on Earth. This same apostolic ministry arrived in Southern Africa through Evangelist Carl G. Klibbe in 1889.",
          ),
          const SizedBox(height: 16),
          _sectionTitle("Growth in Southern Africa"),
          _paragraph(
            "Klibbe's ministry among German-speaking communities led to the emergence of a congregation in 1892. The first church hall was dedicated in 1906. After internal divisions, Apostle Klibbe led the Old Apostolic Church, expanding the faith across the region.",
          ),
          const SizedBox(height: 16),
          _sectionTitle("Rise of Black Apostles"),
          _paragraph(
            "In 1953, Apostle Samuel Hlatshwayo was ordained, followed by J.S. Ndlovu in 1961. Due to apartheid-era tensions, Apostle Ndlovu founded The Twelve Apostles Church in Africa in 1968, later leading to the formation of TACC in 1978 under Apostle S.D. Phakathi.",
          ),
          const SizedBox(height: 16),
          _sectionTitle("Challenges & Unity"),
          _paragraph(
            "Following the disappearance and return of Apostle Ndlovu from Mozambique, internal divisions resulted in Apostle Phakathi founding The Twelve Apostles Church In Christ. The church grew significantly, especially among the youth and in countries like Mozambique, Zimbabwe, and Lesotho.",
          ),
          const SizedBox(height: 16),
          _sectionTitle("Modern Era"),
          _paragraph(
            "Under Apostle Mlangeni and Deputy Khumalo, the church has grown over 300% since 1994. The farm at Umkomaas serves as the headquarters. New Apostles have been ordained across South Africa and neighboring nations, and the church continues to thrive in Malawi, Angola, and D.R. Congo.",
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    ),
  );

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("•  ", style: TextStyle(fontSize: 16)),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
      ],
    ),
  );

  Widget _paragraph(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Text(text, style: const TextStyle(fontSize: 16, height: 1.5)),
  );
}
