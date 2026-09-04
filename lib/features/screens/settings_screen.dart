import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_controller.dart';
import '../../core/env.dart';
import '../../core/theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override ConsumerState<SettingsScreen> createState()=>_SettingsScreenState();
}
class _SettingsScreenState extends ConsumerState<SettingsScreen>{
  bool autoUpdate=true; String language='system';
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Configuración')),
    body:ListView(padding:const EdgeInsets.all(18),children:[
      GlassCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Aplicación',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:autoUpdate,title:const Text('Actualización automática'),onChanged:(v)=>setState(()=>autoUpdate=v)),
        DropdownButtonFormField<String>(initialValue:language,decoration:const InputDecoration(labelText:'Idioma'),items:const [
          DropdownMenuItem(value:'system',child:Text('Sistema')),DropdownMenuItem(value:'es',child:Text('Español')),DropdownMenuItem(value:'en',child:Text('English')),DropdownMenuItem(value:'pt',child:Text('Português'))],onChanged:(v)=>setState(()=>language=v??'system')),
      ])),
      const SizedBox(height:16),
      GlassCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Entorno',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:8),Text('API: ${Env.apiBaseUrl}',style:const TextStyle(color:AppColors.muted)),Text('App: ${Env.appVersion}',style:const TextStyle(color:AppColors.muted)),Text('Auth redirect: ${Env.authRedirectUrl}',style:const TextStyle(color:AppColors.muted))])),
      const SizedBox(height:16),
      FilledButton.icon(onPressed:()=>_logout(context),icon:const Icon(Icons.logout),label:const Text('Cerrar sesión')),
    ]));
  Future<void> _logout(BuildContext context)async{await ref.read(authControllerProvider.notifier).signOut();if(context.mounted)Navigator.pop(context);}
}
