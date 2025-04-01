/*
 * Copyright (c) 2009 The Boeing Company
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *
 */

// This script configures two nodes on an 802.11b physical layer, with
// 802.11b NICs in adhoc mode, and by default, sends one packet of 1000
// (application) bytes to the other node.  The physical layer is configured
// to receive at a fixed RSS (regardless of the distance and transmit
// power); therefore, changing position of the nodes has no effect.
//
// There are a number of command-line options available to control
// the default behavior.  The list of available command-line options
// can be listed with the following command:
// ./ns3 run "wifi-simple-adhoc --help"
//
// For instance, for this configuration, the physical layer will
// stop successfully receiving packets when rss drops below -97 dBm.
// To see this effect, try running:
//
// ./ns3 run "wifi-simple-adhoc --rss=-97 --numPackets=20"
// ./ns3 run "wifi-simple-adhoc --rss=-98 --numPackets=20"
// ./ns3 run "wifi-simple-adhoc --rss=-99 --numPackets=20"
//
// Note that all ns-3 attributes (not just the ones exposed in the below
// script) can be changed at command line; see the documentation.
//
// This script can also be helpful to put the Wifi layer into verbose
// logging mode; this command will turn on all wifi logging:
//
// ./ns3 run "wifi-simple-adhoc --verbose=1"
//
// When you are done, you will notice two pcap trace files in your directory.
// If you have tcpdump installed, you can try this:
//
// tcpdump -r wifi-simple-adhoc-0-0.pcap -nn -tt
//

#include "ns3/command-line.h"
#include "ns3/config.h"
#include "ns3/double.h"
#include "ns3/internet-stack-helper.h"
#include "ns3/ipv4-address-helper.h"
#include "ns3/log.h"
#include "ns3/mobility-helper.h"
#include "ns3/mobility-model.h"
#include "ns3/string.h"
#include "ns3/yans-wifi-channel.h"
#include "ns3/yans-wifi-helper.h"           //add these modules
#include "ns3/flow-monitor-module.h"           // add 4 modules
#include "ns3/internet-module.h"
#include "ns3/network-module.h"
#include "ns3/applications-module.h"

using namespace ns3;

NS_LOG_COMPONENT_DEFINE("WifiSimpleAdhoc");

/**
 * Function called when a packet is received.
 *
 * \param socket The receiving socket.
 */
void
ReceivePacket(Ptr<Socket> socket)
{
    while (socket->Recv())
    {
        NS_LOG_UNCOND("Received one packet!");
    }
}

/**
 * Generate traffic.
 *
 * \param socket The sending socket.
 * \param pktSize The packet size.
 * \param pktCount The packet count.
 * \param pktInterval The interval between two packets.
 */
static void
GenerateTraffic(Ptr<Socket> socket, uint32_t pktSize, uint32_t pktCount, Time pktInterval)
{
    if (pktCount > 0)
    {
        socket->Send(Create<Packet>(pktSize));
        Simulator::Schedule(pktInterval,
                            &GenerateTraffic,
                            socket,
                            pktSize,
                            pktCount - 1,
                            pktInterval);
    }
    else
    {
        socket->Close();
    }
}

int
main(int argc, char* argv[])
{
    std::string phyMode("DsssRate1Mbps");
    dBm_u rss{-80};
    uint32_t packetSize{1000}; // bytes
    uint32_t numPackets{1};
    Time interPacketInterval{"1s"};
    bool verbose{false};
    
     double simulationTime = 10; // seconds               //add these 3 line
    std::string transportProt = "Udp";
    std::string socketType;

                                                     //add these

    if (transportProt == "Tcp")
    {
        socketType = "ns3::TcpSocketFactory";
    }
    else
    {
        socketType = "ns3::UdpSocketFactory";
    }                                 //till here


    CommandLine cmd(__FILE__);
    cmd.AddValue("phyMode", "Wifi Phy mode", phyMode);
    cmd.AddValue("rss", "received signal strength", rss);
    cmd.AddValue("packetSize", "size of application packet sent", packetSize);
    cmd.AddValue("numPackets", "number of packets generated", numPackets);
    cmd.AddValue("interval", "interval between packets", interPacketInterval);
    cmd.AddValue("verbose", "turn on all WifiNetDevice log components", verbose);
    cmd.Parse(argc, argv);

    // Fix non-unicast data rate to be the same as that of unicast
    Config::SetDefault("ns3::WifiRemoteStationManager::NonUnicastMode", StringValue(phyMode));
                                                                                                            //add these lines
                                                                                                            
                                                                                                            
    Config::SetDefault("ns3::WifiRemoteStationManager::RtsCtsThreshold", UintegerValue(0)); // Enable RTS/CTS
    // or
   // Config::SetDefault("ns3::WifiRemoteStationManager::RtsCtsThreshold", UintegerValue(999999)); // Disable RTS/CTS
    NodeContainer c;
    c.Create(10);                                                                         //nodes creation
                                             
                                             
    // The below set of helpers will help us to put together the wifi NICs we want
    WifiHelper wifi;
    if (verbose)
    {
        WifiHelper::EnableLogComponents(); // Turn on all Wifi logging
    }
    wifi.SetStandard(WIFI_STANDARD_80211b);

    YansWifiPhyHelper wifiPhy;
    // This is one parameter that matters when using FixedRssLossModel
    // set it to zero; otherwise, gain will be added
    wifiPhy.Set("RxGain", DoubleValue(0));
    // ns-3 supports RadioTap and Prism tracing extensions for 802.11b
    wifiPhy.SetPcapDataLinkType(WifiPhyHelper::DLT_IEEE802_11_RADIO);

    YansWifiChannelHelper wifiChannel;
    wifiChannel.SetPropagationDelay("ns3::ConstantSpeedPropagationDelayModel");
    // The below FixedRssLossModel will cause the rss to be fixed regardless
    // of the distance between the two stations, and the transmit power
    wifiChannel.AddPropagationLoss("ns3::FixedRssLossModel", "Rss", DoubleValue(rss));
    wifiPhy.SetChannel(wifiChannel.Create());

    // Add a mac and disable rate control
    WifiMacHelper wifiMac;
    wifi.SetRemoteStationManager("ns3::ConstantRateWifiManager",
                                 "DataMode",
                                 StringValue(phyMode),
                                 "ControlMode",
                                 StringValue(phyMode));
    // Set it to adhoc mode
    wifiMac.SetType("ns3::AdhocWifiMac");
    NetDeviceContainer devices = wifi.Install(wifiPhy, wifiMac, c);

    // Note that with FixedRssLossModel, the positions below are not
    // used for received signal strength.
    MobilityHelper mobility;
    Ptr<ListPositionAllocator> positionAlloc = CreateObject<ListPositionAllocator>();
    positionAlloc->Add(Vector(0.0, 0.0, 0.0));
    positionAlloc->Add(Vector(5.0, 0.0, 0.0));
    mobility.SetPositionAllocator(positionAlloc);
    mobility.SetMobilityModel("ns3::ConstantPositionMobilityModel");
    mobility.Install(c);

    InternetStackHelper internet;
    internet.Install(c);

    Ipv4AddressHelper ipv4;
    NS_LOG_INFO("Assign IP Addresses.");
    ipv4.SetBase("10.1.1.0", "255.255.255.0");
    Ipv4InterfaceContainer i = ipv4.Assign(devices);
   
   /*
    TypeId tid = TypeId::LookupByName("ns3::UdpSocketFactory");
    Ptr<Socket> recvSink = Socket::CreateSocket(c.Get(0), tid);
    InetSocketAddress local = InetSocketAddress(Ipv4Address::GetAny(), 80);
    recvSink->Bind(local);
    recvSink->SetRecvCallback(MakeCallback(&ReceivePacket));

    Ptr<Socket> source = Socket::CreateSocket(c.Get(1), tid);
    InetSocketAddress remote = InetSocketAddress(Ipv4Address("255.255.255.255"), 80);
    source->SetAllowBroadcast(true);
    source->Connect(remote);

    // Tracing
    wifiPhy.EnablePcap("wifi-simple-adhoc", devices);

    // Output what we are doing
    NS_LOG_UNCOND("Testing " << numPackets << " packets sent with receiver rss " << rss);

    Simulator::ScheduleWithContext(source->GetNode()->GetId(),
                                   Seconds(1.0),
                                   &GenerateTraffic,
                                   source,
                                   packetSize,
                                   numPackets,
                                   interPacketInterval);

    Simulator::Run();
    Simulator::Destroy();

    return 0;
}
*/                                                                                           //delete these lines
//add these from lab 1

    uint16_t port = 7;
    Address localAddress(InetSocketAddress(Ipv4Address::GetAny(), port));
    PacketSinkHelper packetSinkHelper(socketType, localAddress);
    ApplicationContainer sinkApp = packetSinkHelper.Install(c.Get(8));                    //reciever

    sinkApp.Start(Seconds(0.0));
    sinkApp.Stop(Seconds(simulationTime + 0.1));

    uint32_t payloadSize = 1448;
    Config::SetDefault("ns3::TcpSocket::SegmentSize", UintegerValue(payloadSize));

    OnOffHelper onoff(socketType, Ipv4Address::GetAny());
    onoff.SetAttribute("OnTime", StringValue("ns3::ConstantRandomVariable[Constant=1]"));
    onoff.SetAttribute("OffTime", StringValue("ns3::ConstantRandomVariable[Constant=0]"));
    onoff.SetAttribute("PacketSize", UintegerValue(payloadSize));
    onoff.SetAttribute("DataRate", StringValue("50Mbps")); // bit/s                      //vary data rate
    ApplicationContainer apps;

    InetSocketAddress rmt(i.GetAddress(8), port);            //destination
    onoff.SetAttribute("Remote", AddressValue(rmt));
    onoff.SetAttribute("Tos", UintegerValue(0xb8));
    apps.Add(onoff.Install(c.Get(2)));                                               //sender
    apps.Start(Seconds(1.0)); 
    apps.Stop(Seconds(simulationTime + 0.1));
    
    //tcp flow

    FlowMonitorHelper flowmon;
    Ptr<FlowMonitor> monitor = flowmon.InstallAll();

    Simulator::Stop(Seconds(simulationTime + 5));
    Simulator::Run();

    Ptr<Ipv4FlowClassifier> classifier = DynamicCast<Ipv4FlowClassifier>(flowmon.GetClassifier());
    std::map<FlowId, FlowMonitor::FlowStats> stats = monitor->GetFlowStats();
    std::cout << std::endl << "*** Flow monitor statistics ***" << std::endl;
    std::cout << "  Tx Packets/Bytes:   " << stats[1].txPackets << " / " << stats[1].txBytes
              << std::endl;
    /*std::cout << "  Offered Load: "
              << stats[1].txBytes * 8.0 /
                     (stats[1].timeLastTxPacket.GetSeconds() -
                      stats[1].timeFirstTxPacket.GetSeconds()) /
                     1000000
              << " Mbps" << std::endl;*/
    std::cout << "  Rx Packets/Bytes:   " << stats[1].rxPackets << " / " << stats[1].rxBytes
              << std::endl;
    /*uint32_t packetsDroppedByQueueDisc = 0;
    uint64_t bytesDroppedByQueueDisc = 0;
    if (stats[1].packetsDropped.size() > Ipv4FlowProbe::DROP_QUEUE_DISC)
    {
        packetsDroppedByQueueDisc = stats[1].packetsDropped[Ipv4FlowProbe::DROP_QUEUE_DISC];
        bytesDroppedByQueueDisc = stats[1].bytesDropped[Ipv4FlowProbe::DROP_QUEUE_DISC];
    }
    std::cout << "  Packets/Bytes Dropped by Queue Disc:   " << packetsDroppedByQueueDisc << " / "
              << bytesDroppedByQueueDisc << std::endl;*/
    uint32_t packetsDroppedByNetDevice = 0;
    uint64_t bytesDroppedByNetDevice = 0;
    /*if (stats[1].packetsDropped.size() > Ipv4FlowProbe::DROP_QUEUE)
    {
        packetsDroppedByNetDevice = stats[1].packetsDropped[Ipv4FlowProbe::DROP_QUEUE];
        bytesDroppedByNetDevice = stats[1].bytesDropped[Ipv4FlowProbe::DROP_QUEUE];
    }*/
    std::cout << "  Packets/Bytes Dropped by NetDevice:   " << packetsDroppedByNetDevice << " / " //change this in exams
              << bytesDroppedByNetDevice << std::endl;
              
    std::cout << "  Throughput: "
              << stats[1].rxBytes * 8.0 /
                     (stats[1].timeLastRxPacket.GetSeconds() -
                      stats[1].timeFirstRxPacket.GetSeconds()) /
                     1000000
              << " Mbps" << std::endl;
    std::cout << "  Mean delay:   " << stats[1].delaySum.GetSeconds() / stats[1].rxPackets
              << std::endl;
    std::cout << "  Mean jitter:   " << stats[1].jitterSum.GetSeconds() / (stats[1].rxPackets - 1)
              << std::endl;
    /*auto dscpVec = classifier->GetDscpCounts(1);
    for (auto p : dscpVec)
    {
        std::cout << "  DSCP value:   0x" << std::hex << static_cast<uint32_t>(p.first) << std::dec
                  << "  count:   " << p.second << std::endl;
    }
**/
    Simulator::Destroy();
/*
    std::cout << std::endl << "*** Application statistics ***" << std::endl;
    double thr = 0;
    uint64_t totalPacketsThr = DynamicCast<PacketSink>(sinkApp.Get(0))->GetTotalRx();
    thr = totalPacketsThr * 8 / (simulationTime * 1000000.0); // Mbit/s
    std::cout << "  Rx Bytes: " << totalPacketsThr << std::endl;
    std::cout << "  Average Goodput: " << thr << " Mbit/s" << std::endl;
    std::cout << std::endl << "*** TC Layer statistics ***" << std::endl;
    std::cout << q->GetStats() << std::endl;
    */
    return 0;
}
