//
//  QuickCheckWidget.swift
//  QuickCheckWidget
//
//  Created by João Gabriel Pozzobon dos Santos on 23/06/20.
//

import WidgetKit
import SwiftUI
import Intents

struct Provider: IntentTimelineProvider {
    public func snapshot(for configuration: ConfigurationIntent, with context: Context, completion: @escaping (CoronaDataEntry) -> ()) {
        let fakeData = CoronaData(confirmed: 0, deaths: 0, recovered: 0, total: 1)
        let entry = CoronaDataEntry(date: Date(), configuration: configuration, data: fakeData)
        completion(entry)
    }

    public func timeline(for configuration: ConfigurationIntent, with context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!

        CoronaDataLoader.fetch { result in
            let data: CoronaData
            if case .success(let fetchedData) = result {
                data = fetchedData
            } else {
                data = CoronaData(confirmed: 0, deaths: 0, recovered: 0, total: 1)
            }
            let entry = CoronaDataEntry(date: currentDate, configuration: configuration, data: data)
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
}

struct CoronaDataEntry: TimelineEntry {
    public let date: Date
    public let configuration: ConfigurationIntent
    public let data: CoronaData
}

struct PlaceholderView : View {
    var body: some View {
        Text("Placeholder View")
    }
}

struct QuickCheckWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        HStack {
            VStack (alignment: .leading) {
                TitleLabel(text: "Confirmed")
                NumberLabel(number: entry.data.confirmed)
                Spacer()
                TitleLabel(text: "Deaths")
                NumberLabel(number: entry.data.deaths)
                Spacer()
                TitleLabel(text: "Recovered")
                NumberLabel(number: entry.data.recovered)
            }
            
            Spacer()
            
            let yellow = calculateProportion(portion: entry.data.confirmed, total: entry.data.total)
            let red = calculateProportion(portion: entry.data.deaths, total: entry.data.total)
            let green = calculateProportion(portion: entry.data.recovered, total: entry.data.total)
            BarView(yellow: yellow, red: red, green: green).frame(minWidth: 0, maxWidth: 10, minHeight: 0, maxHeight: 200)
        }.padding(25)
    }
}

struct TitleLabel: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
    }
}

struct NumberLabel: View {
    var number: Int
    var body: some View {
        Text(String(format: "%d", locale: Locale.current, number))
            .font(.system(size: 15, weight: .light))
    }
}

func calculateProportion(portion: Int, total: Int) -> CGFloat {
    return CGFloat(portion) /
        CGFloat(total)
}


struct BarView: View {
    var yellow: CGFloat
    var red: CGFloat
    var green: CGFloat
    
    var body: some View {
        GeometryReader { metrics in
            VStack (alignment: .center, spacing: 0) {
                Color.yellow.frame(height: metrics.size.height * yellow)
                Color.red.frame(height: metrics.size.height * red)
                Color.green.frame(height: metrics.size.height * green)
            }.cornerRadius(5)
        }
    }
}

struct CoronaData {
    let confirmed: Int
    let deaths: Int
    let recovered: Int
    let total: Int
}

struct CoronaDataLoader {
    static func fetch(completion: @escaping (Result<CoronaData, Error>) -> Void) {
        let coronaDataURL = URL(string: "https://api.covid19api.com/summary")!
        let task = URLSession.shared.dataTask(with: coronaDataURL) { (data, response, error) in
            guard error == nil else {
                completion(.failure(error!))
                return
            }
            let coronaData = getStatistics(fromData: data!)
            completion(.success(coronaData))
        }
        task.resume()
    }
    
    static func getStatistics(fromData data: Foundation.Data) -> CoronaData {
        let json = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
        
        let global = json["Global"] as! [String: Any]
        
        let confirmed = global["TotalConfirmed"] as! Int
        let deaths = global["TotalDeaths"] as! Int
        let recovered = global["TotalRecovered"] as! Int
        
        let total = confirmed+deaths+recovered
        return CoronaData(confirmed: confirmed, deaths: deaths, recovered: recovered, total: total)
    }
}

@main
struct QuickCheckWidget: Widget {
    private let kind: String = "QuickCheckWidget"

    public var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind,
            intent: ConfigurationIntent.self,
            provider: Provider(),
            placeholder: PlaceholderView()
        ) { entry in
            QuickCheckWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Check")
        .description("Take a quick look at the newest COVID-19 statistics.")
        .supportedFamilies([.systemSmall])
    }
}
