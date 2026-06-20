import 'package:flutter/material.dart';

import '../models/recommendation_model.dart';

final List<RecommendationModel> caregiverRecommendations = [
  RecommendationModel(
    title: 'Salud física',
    icon: Icons.fitness_center,
    color: const Color(0xFFFFF5A8),
    recommendations: [
      'Toma agua cada 60 minutos.',
      'Carga solo cosas ligeras.',
      'Mueve tobillos y hombros antes de levantarte.',
      'Descansa cinco minutos si te sientes cansado.',
      'Camina 10 minutos en un lugar seguro.',
      'Haz estiramientos suaves al despertar.',
      'Evita levantar objetos pesados.',
      'Si sientes dolor fuerte, avisa a un familiar o profesional de salud.',
    ],
  ),
  RecommendationModel(
    title: 'Salud mental',
    icon: Icons.self_improvement,
    color: const Color(0xFFF29BA0),
    recommendations: [
      'Respira profundo durante un minuto.',
      'Habla con alguien de confianza si te sientes triste.',
      'Escucha música tranquila.',
      'Realiza una actividad que disfrutes.',
      'Evita hacer muchas tareas al mismo tiempo.',
      'Date permiso de descansar.',
    ],
  ),
  RecommendationModel(
    title: 'Memoria',
    icon: Icons.memory,
    color: const Color(0xFFAED4F5),
    recommendations: [
      'Anota las actividades importantes del día.',
      'Repite en voz alta lo que necesitas recordar.',
      'Usa calendarios o notas visibles.',
      'Relaciona nombres con imágenes o lugares.',
      'Haz juegos sencillos de memoria.',
    ],
  ),
  RecommendationModel(
    title: 'Rutina y sueño',
    icon: Icons.dark_mode,
    color: const Color(0xFFB4EFA4),
    recommendations: [
      'Duerme y despierta a la misma hora.',
      'Evita usar el celular antes de dormir.',
      'Mantén una rutina tranquila por la noche.',
      'Toma una bebida tibia sin cafeína.',
      'Evita dormir siestas muy largas.',
    ],
  ),
  RecommendationModel(
    title: 'Seguridad',
    icon: Icons.shield,
    color: const Color(0xFFC993F4),
    recommendations: [
      'Mantén los pasillos libres de objetos.',
      'Usa zapatos cómodos y cerrados.',
      'Coloca buena iluminación por la noche.',
      'Ten números de emergencia a la mano.',
      'Evita pisos mojados o resbalosos.',
    ],
  ),
];