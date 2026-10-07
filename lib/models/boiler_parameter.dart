import 'package:flutter/material.dart';

/// Every sensor value a boiler unit can report. Not every physical
/// installation wires up all of these, so each BoilerDevice tracks
/// which subset it actually supports — that's what makes one screen
/// reusable across different boiler configurations.
///
/// Note this is DC voltage (not three-phase AC), and the three
/// element currents are per-heating-element draw, not AC phase legs.
enum BoilerParameter {
  voltage,
  mainCurrent,
  temperature,
  pressure,
  elementCurrent1,
  elementCurrent2,
  elementCurrent3,
}

class BoilerParameterInfo {
  final String label;
  final String unit;
  final IconData icon;
  final Color color;

  const BoilerParameterInfo({
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
  });
}

const Map<BoilerParameter, BoilerParameterInfo> boilerParameterInfo = {
  BoilerParameter.voltage: BoilerParameterInfo(
    label: 'Voltage',
    unit: 'VDC',
    icon: Icons.bolt,
    color: Color(0xFF5AA9E0),
  ),
  BoilerParameter.mainCurrent: BoilerParameterInfo(
    label: 'Main current',
    unit: 'A',
    icon: Icons.bolt,
    color: Color(0xFFE8823C),
  ),
  BoilerParameter.temperature: BoilerParameterInfo(
    label: 'Temperature',
    unit: 'C',
    icon: Icons.thermostat,
    color: Color(0xFFE8683C),
  ),
  BoilerParameter.pressure: BoilerParameterInfo(
    label: 'Pressure',
    unit: 'kPa',
    icon: Icons.speed,
    color: Color(0xFF4FD1A5),
  ),
  BoilerParameter.elementCurrent1: BoilerParameterInfo(
    label: 'Element 1 current',
    unit: 'A',
    icon: Icons.electrical_services,
    color: Color(0xFF4FD1A5),
  ),
  BoilerParameter.elementCurrent2: BoilerParameterInfo(
    label: 'Element 2 current',
    unit: 'A',
    icon: Icons.electrical_services,
    color: Color(0xFF4FD1A5),
  ),
  BoilerParameter.elementCurrent3: BoilerParameterInfo(
    label: 'Element 3 current',
    unit: 'A',
    icon: Icons.electrical_services,
    color: Color(0xFF4FD1A5),
  ),
};
