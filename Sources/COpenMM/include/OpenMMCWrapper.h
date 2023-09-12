
#ifndef OPENMM_CWRAPPER_H_
#define OPENMM_CWRAPPER_H_

#ifndef OPENMM_EXPORT
#define OPENMM_EXPORT
#endif

/* Global Constants */

static const double OpenMM_NmPerAngstrom =  0.1;
static const double OpenMM_AngstromsPerNm =  10.0;
static const double OpenMM_PsPerFs =  0.001;
static const double OpenMM_FsPerPs =  1000.0;
static const double OpenMM_KJPerKcal =  4.184;
static const double OpenMM_KcalPerKJ =  1.0/4.184;
static const double OpenMM_RadiansPerDegree =  3.1415926535897932385/180.0;
static const double OpenMM_DegreesPerRadian =  180.0/3.1415926535897932385;
static const double OpenMM_SigmaPerVdwRadius =  1.7817974362806786095;
static const double OpenMM_VdwRadiusPerSigma =  .56123102415468649070;

/* Type Declarations */

typedef struct OpenMM_Context_struct OpenMM_Context;
typedef struct OpenMM_TabulatedFunction_struct OpenMM_TabulatedFunction;
typedef struct OpenMM_Discrete2DFunction_struct OpenMM_Discrete2DFunction;
typedef struct OpenMM_Force_struct OpenMM_Force;
typedef struct OpenMM_CustomAngleForce_struct OpenMM_CustomAngleForce;
typedef struct OpenMM_CustomNonbondedForce_struct OpenMM_CustomNonbondedForce;
typedef struct OpenMM_AndersenThermostat_struct OpenMM_AndersenThermostat;
typedef struct OpenMM_VirtualSite_struct OpenMM_VirtualSite;
typedef struct OpenMM_ThreeParticleAverageSite_struct OpenMM_ThreeParticleAverageSite;
typedef struct OpenMM_CustomHbondForce_struct OpenMM_CustomHbondForce;
typedef struct OpenMM_Continuous1DFunction_struct OpenMM_Continuous1DFunction;
typedef struct OpenMM_Discrete3DFunction_struct OpenMM_Discrete3DFunction;
typedef struct OpenMM_OpenMMException_struct OpenMM_OpenMMException;
typedef struct OpenMM_MonteCarloFlexibleBarostat_struct OpenMM_MonteCarloFlexibleBarostat;
typedef struct OpenMM_MonteCarloBarostat_struct OpenMM_MonteCarloBarostat;
typedef struct OpenMM_GayBerneForce_struct OpenMM_GayBerneForce;
typedef struct OpenMM_TwoParticleAverageSite_struct OpenMM_TwoParticleAverageSite;
typedef struct OpenMM_LocalCoordinatesSite_struct OpenMM_LocalCoordinatesSite;
typedef struct OpenMM_CustomBondForce_struct OpenMM_CustomBondForce;
typedef struct OpenMM_State_struct OpenMM_State;
typedef struct OpenMM_HarmonicAngleForce_struct OpenMM_HarmonicAngleForce;
typedef struct OpenMM_CustomManyParticleForce_struct OpenMM_CustomManyParticleForce;
typedef struct OpenMM_Integrator_struct OpenMM_Integrator;
typedef struct OpenMM_VariableVerletIntegrator_struct OpenMM_VariableVerletIntegrator;
typedef struct OpenMM_MonteCarloMembraneBarostat_struct OpenMM_MonteCarloMembraneBarostat;
typedef struct OpenMM_MonteCarloAnisotropicBarostat_struct OpenMM_MonteCarloAnisotropicBarostat;
typedef struct OpenMM_NoseHooverIntegrator_struct OpenMM_NoseHooverIntegrator;
typedef struct OpenMM_CustomCVForce_struct OpenMM_CustomCVForce;
typedef struct OpenMM_NonbondedForce_struct OpenMM_NonbondedForce;
typedef struct OpenMM_PeriodicTorsionForce_struct OpenMM_PeriodicTorsionForce;
typedef struct OpenMM_BrownianIntegrator_struct OpenMM_BrownianIntegrator;
typedef struct OpenMM_GBSAOBCForce_struct OpenMM_GBSAOBCForce;
typedef struct OpenMM_VerletIntegrator_struct OpenMM_VerletIntegrator;
typedef struct OpenMM_NoseHooverChain_struct OpenMM_NoseHooverChain;
typedef struct OpenMM_LangevinMiddleIntegrator_struct OpenMM_LangevinMiddleIntegrator;
typedef struct OpenMM_LocalEnergyMinimizer_struct OpenMM_LocalEnergyMinimizer;
typedef struct OpenMM_LangevinIntegrator_struct OpenMM_LangevinIntegrator;
typedef struct OpenMM_VariableLangevinIntegrator_struct OpenMM_VariableLangevinIntegrator;
typedef struct OpenMM_CustomIntegrator_struct OpenMM_CustomIntegrator;
typedef struct OpenMM_RBTorsionForce_struct OpenMM_RBTorsionForce;
typedef struct OpenMM_CompoundIntegrator_struct OpenMM_CompoundIntegrator;
typedef struct OpenMM_System_struct OpenMM_System;
typedef struct OpenMM_CustomCompoundBondForce_struct OpenMM_CustomCompoundBondForce;
typedef struct OpenMM_CustomCentroidBondForce_struct OpenMM_CustomCentroidBondForce;
typedef struct OpenMM_CMAPTorsionForce_struct OpenMM_CMAPTorsionForce;
typedef struct OpenMM_Continuous3DFunction_struct OpenMM_Continuous3DFunction;
typedef struct OpenMM_OutOfPlaneSite_struct OpenMM_OutOfPlaneSite;
typedef struct OpenMM_Discrete1DFunction_struct OpenMM_Discrete1DFunction;
typedef struct OpenMM_CustomTorsionForce_struct OpenMM_CustomTorsionForce;
typedef struct OpenMM_HarmonicBondForce_struct OpenMM_HarmonicBondForce;
typedef struct OpenMM_CustomGBForce_struct OpenMM_CustomGBForce;
typedef struct OpenMM_RMSDForce_struct OpenMM_RMSDForce;
typedef struct OpenMM_CustomExternalForce_struct OpenMM_CustomExternalForce;
typedef struct OpenMM_Continuous2DFunction_struct OpenMM_Continuous2DFunction;
typedef struct OpenMM_CMMotionRemover_struct OpenMM_CMMotionRemover;
typedef struct OpenMM_Platform_struct OpenMM_Platform;

typedef struct OpenMM_Vec3Array_struct OpenMM_Vec3Array;
typedef struct OpenMM_StringArray_struct OpenMM_StringArray;
typedef struct OpenMM_BondArray_struct OpenMM_BondArray;
typedef struct OpenMM_ParameterArray_struct OpenMM_ParameterArray;
typedef struct OpenMM_PropertyArray_struct OpenMM_PropertyArray;
typedef struct OpenMM_DoubleArray_struct OpenMM_DoubleArray;
typedef struct OpenMM_IntArray_struct OpenMM_IntArray;
typedef struct OpenMM_IntSet_struct OpenMM_IntSet;
typedef struct {double x, y, z;} OpenMM_Vec3;

typedef enum {OpenMM_False = 0, OpenMM_True = 1} OpenMM_Boolean;

#if defined(__cplusplus)
extern "C" {
#endif

/* OpenMM_Vec3 */
extern OPENMM_EXPORT OpenMM_Vec3 OpenMM_Vec3_scale(const OpenMM_Vec3 vec, double scale);

/* OpenMM_Vec3Array */
extern OPENMM_EXPORT OpenMM_Vec3Array* OpenMM_Vec3Array_create(int size);
extern OPENMM_EXPORT void OpenMM_Vec3Array_destroy(OpenMM_Vec3Array* array);
extern OPENMM_EXPORT int OpenMM_Vec3Array_getSize(const OpenMM_Vec3Array* array);
extern OPENMM_EXPORT void OpenMM_Vec3Array_resize(OpenMM_Vec3Array* array, int size);
extern OPENMM_EXPORT void OpenMM_Vec3Array_append(OpenMM_Vec3Array* array, const OpenMM_Vec3 vec);
extern OPENMM_EXPORT void OpenMM_Vec3Array_set(OpenMM_Vec3Array* array, int index, const OpenMM_Vec3 vec);
extern OPENMM_EXPORT const OpenMM_Vec3* OpenMM_Vec3Array_get(const OpenMM_Vec3Array* array, int index);

/* OpenMM_StringArray */
extern OPENMM_EXPORT OpenMM_StringArray* OpenMM_StringArray_create(int size);
extern OPENMM_EXPORT void OpenMM_StringArray_destroy(OpenMM_StringArray* array);
extern OPENMM_EXPORT int OpenMM_StringArray_getSize(const OpenMM_StringArray* array);
extern OPENMM_EXPORT void OpenMM_StringArray_resize(OpenMM_StringArray* array, int size);
extern OPENMM_EXPORT void OpenMM_StringArray_append(OpenMM_StringArray* array, const char* string);
extern OPENMM_EXPORT void OpenMM_StringArray_set(OpenMM_StringArray* array, int index, const char* string);
extern OPENMM_EXPORT const char* OpenMM_StringArray_get(const OpenMM_StringArray* array, int index);

/* OpenMM_BondArray */
extern OPENMM_EXPORT OpenMM_BondArray* OpenMM_BondArray_create(int size);
extern OPENMM_EXPORT void OpenMM_BondArray_destroy(OpenMM_BondArray* array);
extern OPENMM_EXPORT int OpenMM_BondArray_getSize(const OpenMM_BondArray* array);
extern OPENMM_EXPORT void OpenMM_BondArray_resize(OpenMM_BondArray* array, int size);
extern OPENMM_EXPORT void OpenMM_BondArray_append(OpenMM_BondArray* array, int particle1, int particle2);
extern OPENMM_EXPORT void OpenMM_BondArray_set(OpenMM_BondArray* array, int index, int particle1, int particle2);
extern OPENMM_EXPORT void OpenMM_BondArray_get(const OpenMM_BondArray* array, int index, int* particle1, int* particle2);

/* OpenMM_ParameterArray */
extern OPENMM_EXPORT int OpenMM_ParameterArray_getSize(const OpenMM_ParameterArray* array);
extern OPENMM_EXPORT double OpenMM_ParameterArray_get(const OpenMM_ParameterArray* array, const char* name);

/* OpenMM_PropertyArray */
extern OPENMM_EXPORT int OpenMM_PropertyArray_getSize(const OpenMM_PropertyArray* array);
extern OPENMM_EXPORT const char* OpenMM_PropertyArray_get(const OpenMM_PropertyArray* array, const char* name);

/* OpenMM_DoubleArray */
extern OPENMM_EXPORT OpenMM_DoubleArray* OpenMM_DoubleArray_create(int size);
extern OPENMM_EXPORT void OpenMM_DoubleArray_destroy(OpenMM_DoubleArray* array);
extern OPENMM_EXPORT int OpenMM_DoubleArray_getSize(const OpenMM_DoubleArray* array);
extern OPENMM_EXPORT void OpenMM_DoubleArray_resize(OpenMM_DoubleArray* array, int size);
extern OPENMM_EXPORT void OpenMM_DoubleArray_append(OpenMM_DoubleArray* array, double value);
extern OPENMM_EXPORT void OpenMM_DoubleArray_set(OpenMM_DoubleArray* array, int index, double value);
extern OPENMM_EXPORT double OpenMM_DoubleArray_get(const OpenMM_DoubleArray* array, int index);

/* OpenMM_IntArray */
extern OPENMM_EXPORT OpenMM_IntArray* OpenMM_IntArray_create(int size);
extern OPENMM_EXPORT void OpenMM_IntArray_destroy(OpenMM_IntArray* array);
extern OPENMM_EXPORT int OpenMM_IntArray_getSize(const OpenMM_IntArray* array);
extern OPENMM_EXPORT void OpenMM_IntArray_resize(OpenMM_IntArray* array, int size);
extern OPENMM_EXPORT void OpenMM_IntArray_append(OpenMM_IntArray* array, int value);
extern OPENMM_EXPORT void OpenMM_IntArray_set(OpenMM_IntArray* array, int index, int value);
extern OPENMM_EXPORT int OpenMM_IntArray_get(const OpenMM_IntArray* array, int index);

/* OpenMM_IntSet */
extern OPENMM_EXPORT OpenMM_IntSet* OpenMM_IntSet_create();
extern OPENMM_EXPORT void OpenMM_IntSet_destroy(OpenMM_IntSet* set);
extern OPENMM_EXPORT int OpenMM_IntSet_getSize(const OpenMM_IntSet* set);
extern OPENMM_EXPORT void OpenMM_IntSet_insert(OpenMM_IntSet* set, int value);

/* These methods need to be handled specially, since their C++ APIs cannot be directly translated to C.
   Unlike the C++ versions, the return value is allocated on the heap, and you must delete it yourself. */
extern OPENMM_EXPORT OpenMM_State* OpenMM_Context_getState(const OpenMM_Context* target, int types, int enforcePeriodicBox);
extern OPENMM_EXPORT OpenMM_State* OpenMM_Context_getState_2(const OpenMM_Context* target, int types, int enforcePeriodicBox, int groups);
extern OPENMM_EXPORT OpenMM_StringArray* OpenMM_Platform_loadPluginsFromDirectory(const char* directory);
extern OPENMM_EXPORT OpenMM_StringArray* OpenMM_Platform_getPluginLoadFailures();
extern OPENMM_EXPORT char* OpenMM_XmlSerializer_serializeSystem(const OpenMM_System* system);
extern OPENMM_EXPORT char* OpenMM_XmlSerializer_serializeState(const OpenMM_State* state);
extern OPENMM_EXPORT char* OpenMM_XmlSerializer_serializeIntegrator(const OpenMM_Integrator* integrator);
extern OPENMM_EXPORT OpenMM_System* OpenMM_XmlSerializer_deserializeSystem(const char* xml);
extern OPENMM_EXPORT OpenMM_State* OpenMM_XmlSerializer_deserializeState(const char* xml);
extern OPENMM_EXPORT OpenMM_Integrator* OpenMM_XmlSerializer_deserializeIntegrator(const char* xml);

/* Context */
extern OPENMM_EXPORT OpenMM_Context* OpenMM_Context_create(const OpenMM_System* system, OpenMM_Integrator* integrator);
extern OPENMM_EXPORT OpenMM_Context* OpenMM_Context_create_2(const OpenMM_System* system, OpenMM_Integrator* integrator, OpenMM_Platform* platform);
extern OPENMM_EXPORT OpenMM_Context* OpenMM_Context_create_3(const OpenMM_System* system, OpenMM_Integrator* integrator, OpenMM_Platform* platform, const OpenMM_PropertyArray* properties);
extern OPENMM_EXPORT void OpenMM_Context_destroy(OpenMM_Context* target);
extern OPENMM_EXPORT const OpenMM_System* OpenMM_Context_getSystem(const OpenMM_Context* target);
extern OPENMM_EXPORT OpenMM_Integrator* OpenMM_Context_getIntegrator(OpenMM_Context* target);
extern OPENMM_EXPORT OpenMM_Platform* OpenMM_Context_getPlatform(OpenMM_Context* target);
extern OPENMM_EXPORT void OpenMM_Context_setState(OpenMM_Context* target, const OpenMM_State* state);
extern OPENMM_EXPORT double OpenMM_Context_getTime(const OpenMM_Context* target);
extern OPENMM_EXPORT void OpenMM_Context_setTime(OpenMM_Context* target, double time);
extern OPENMM_EXPORT long long OpenMM_Context_getStepCount(const OpenMM_Context* target);
extern OPENMM_EXPORT void OpenMM_Context_setStepCount(OpenMM_Context* target, long long count);
extern OPENMM_EXPORT void OpenMM_Context_setPositions(OpenMM_Context* target, const OpenMM_Vec3Array* positions);
extern OPENMM_EXPORT void OpenMM_Context_setVelocities(OpenMM_Context* target, const OpenMM_Vec3Array* velocities);
extern OPENMM_EXPORT void OpenMM_Context_setVelocitiesToTemperature(OpenMM_Context* target, double temperature, int randomSeed);
extern OPENMM_EXPORT const OpenMM_ParameterArray* OpenMM_Context_getParameters(const OpenMM_Context* target);
extern OPENMM_EXPORT double OpenMM_Context_getParameter(const OpenMM_Context* target, const char* name);
extern OPENMM_EXPORT void OpenMM_Context_setParameter(OpenMM_Context* target, const char* name, double value);
extern OPENMM_EXPORT void OpenMM_Context_setPeriodicBoxVectors(OpenMM_Context* target, const OpenMM_Vec3* a, const OpenMM_Vec3* b, const OpenMM_Vec3* c);
extern OPENMM_EXPORT void OpenMM_Context_applyConstraints(OpenMM_Context* target, double tol);
extern OPENMM_EXPORT void OpenMM_Context_applyVelocityConstraints(OpenMM_Context* target, double tol);
extern OPENMM_EXPORT void OpenMM_Context_computeVirtualSites(OpenMM_Context* target);
extern OPENMM_EXPORT void OpenMM_Context_reinitialize(OpenMM_Context* target, OpenMM_Boolean preserveState);

/* TabulatedFunction */
extern OPENMM_EXPORT void OpenMM_TabulatedFunction_destroy(OpenMM_TabulatedFunction* target);
extern OPENMM_EXPORT OpenMM_TabulatedFunction* OpenMM_TabulatedFunction_Copy(const OpenMM_TabulatedFunction* target);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_TabulatedFunction_getPeriodic(const OpenMM_TabulatedFunction* target);
extern OPENMM_EXPORT int OpenMM_TabulatedFunction_getUpdateCount(const OpenMM_TabulatedFunction* target);

/* Discrete2DFunction */
extern OPENMM_EXPORT OpenMM_Discrete2DFunction* OpenMM_Discrete2DFunction_create(int xsize, int ysize, const OpenMM_DoubleArray* values);
extern OPENMM_EXPORT void OpenMM_Discrete2DFunction_destroy(OpenMM_Discrete2DFunction* target);
extern OPENMM_EXPORT void OpenMM_Discrete2DFunction_getFunctionParameters(const OpenMM_Discrete2DFunction* target, int* xsize, int* ysize, OpenMM_DoubleArray* values);
extern OPENMM_EXPORT void OpenMM_Discrete2DFunction_setFunctionParameters(OpenMM_Discrete2DFunction* target, int xsize, int ysize, const OpenMM_DoubleArray* values);
extern OPENMM_EXPORT OpenMM_Discrete2DFunction* OpenMM_Discrete2DFunction_Copy(const OpenMM_Discrete2DFunction* target);

/* Force */
extern OPENMM_EXPORT void OpenMM_Force_destroy(OpenMM_Force* target);
extern OPENMM_EXPORT int OpenMM_Force_getForceGroup(const OpenMM_Force* target);
extern OPENMM_EXPORT void OpenMM_Force_setForceGroup(OpenMM_Force* target, int group);
extern OPENMM_EXPORT const char* OpenMM_Force_getName(const OpenMM_Force* target);
extern OPENMM_EXPORT void OpenMM_Force_setName(OpenMM_Force* target, const char* name);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_Force_usesPeriodicBoundaryConditions(const OpenMM_Force* target);

/* CustomAngleForce */
extern OPENMM_EXPORT OpenMM_CustomAngleForce* OpenMM_CustomAngleForce_create(const char* energy);
extern OPENMM_EXPORT void OpenMM_CustomAngleForce_destroy(OpenMM_CustomAngleForce* target);
extern OPENMM_EXPORT int OpenMM_CustomAngleForce_getNumAngles(const OpenMM_CustomAngleForce* target);
extern OPENMM_EXPORT int OpenMM_CustomAngleForce_getNumPerAngleParameters(const OpenMM_CustomAngleForce* target);
extern OPENMM_EXPORT int OpenMM_CustomAngleForce_getNumGlobalParameters(const OpenMM_CustomAngleForce* target);
extern OPENMM_EXPORT int OpenMM_CustomAngleForce_getNumEnergyParameterDerivatives(const OpenMM_CustomAngleForce* target);
extern OPENMM_EXPORT const char* OpenMM_CustomAngleForce_getEnergyFunction(const OpenMM_CustomAngleForce* target);
extern OPENMM_EXPORT void OpenMM_CustomAngleForce_setEnergyFunction(OpenMM_CustomAngleForce* target, const char* energy);
extern OPENMM_EXPORT int OpenMM_CustomAngleForce_addPerAngleParameter(OpenMM_CustomAngleForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomAngleForce_getPerAngleParameterName(const OpenMM_CustomAngleForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomAngleForce_setPerAngleParameterName(OpenMM_CustomAngleForce* target, int index, const char* name);
extern OPENMM_EXPORT int OpenMM_CustomAngleForce_addGlobalParameter(OpenMM_CustomAngleForce* target, const char* name, double defaultValue);
extern OPENMM_EXPORT const char* OpenMM_CustomAngleForce_getGlobalParameterName(const OpenMM_CustomAngleForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomAngleForce_setGlobalParameterName(OpenMM_CustomAngleForce* target, int index, const char* name);
extern OPENMM_EXPORT double OpenMM_CustomAngleForce_getGlobalParameterDefaultValue(const OpenMM_CustomAngleForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomAngleForce_setGlobalParameterDefaultValue(OpenMM_CustomAngleForce* target, int index, double defaultValue);
extern OPENMM_EXPORT void OpenMM_CustomAngleForce_addEnergyParameterDerivative(OpenMM_CustomAngleForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomAngleForce_getEnergyParameterDerivativeName(const OpenMM_CustomAngleForce* target, int index);
extern OPENMM_EXPORT int OpenMM_CustomAngleForce_addAngle(OpenMM_CustomAngleForce* target, int particle1, int particle2, int particle3, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomAngleForce_getAngleParameters(const OpenMM_CustomAngleForce* target, int index, int* particle1, int* particle2, int* particle3, OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomAngleForce_setAngleParameters(OpenMM_CustomAngleForce* target, int index, int particle1, int particle2, int particle3, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomAngleForce_updateParametersInContext(OpenMM_CustomAngleForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT void OpenMM_CustomAngleForce_setUsesPeriodicBoundaryConditions(OpenMM_CustomAngleForce* target, OpenMM_Boolean periodic);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_CustomAngleForce_usesPeriodicBoundaryConditions(const OpenMM_CustomAngleForce* target);

/* CustomNonbondedForce */
typedef enum {
  OpenMM_CustomNonbondedForce_NoCutoff = 0, OpenMM_CustomNonbondedForce_CutoffNonPeriodic = 1, OpenMM_CustomNonbondedForce_CutoffPeriodic = 2
} OpenMM_CustomNonbondedForce_NonbondedMethod;

extern OPENMM_EXPORT OpenMM_CustomNonbondedForce* OpenMM_CustomNonbondedForce_create(const char* energy);
extern OPENMM_EXPORT OpenMM_CustomNonbondedForce* OpenMM_CustomNonbondedForce_create_2(const OpenMM_CustomNonbondedForce* rhs);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_destroy(OpenMM_CustomNonbondedForce* target);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_getNumParticles(const OpenMM_CustomNonbondedForce* target);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_getNumExclusions(const OpenMM_CustomNonbondedForce* target);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_getNumPerParticleParameters(const OpenMM_CustomNonbondedForce* target);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_getNumGlobalParameters(const OpenMM_CustomNonbondedForce* target);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_getNumTabulatedFunctions(const OpenMM_CustomNonbondedForce* target);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_getNumFunctions(const OpenMM_CustomNonbondedForce* target);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_getNumComputedValues(const OpenMM_CustomNonbondedForce* target);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_getNumInteractionGroups(const OpenMM_CustomNonbondedForce* target);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_getNumEnergyParameterDerivatives(const OpenMM_CustomNonbondedForce* target);
extern OPENMM_EXPORT const char* OpenMM_CustomNonbondedForce_getEnergyFunction(const OpenMM_CustomNonbondedForce* target);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_setEnergyFunction(OpenMM_CustomNonbondedForce* target, const char* energy);
extern OPENMM_EXPORT OpenMM_CustomNonbondedForce_NonbondedMethod OpenMM_CustomNonbondedForce_getNonbondedMethod(const OpenMM_CustomNonbondedForce* target);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_setNonbondedMethod(OpenMM_CustomNonbondedForce* target, OpenMM_CustomNonbondedForce_NonbondedMethod method);
extern OPENMM_EXPORT double OpenMM_CustomNonbondedForce_getCutoffDistance(const OpenMM_CustomNonbondedForce* target);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_setCutoffDistance(OpenMM_CustomNonbondedForce* target, double distance);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_CustomNonbondedForce_getUseSwitchingFunction(const OpenMM_CustomNonbondedForce* target);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_setUseSwitchingFunction(OpenMM_CustomNonbondedForce* target, OpenMM_Boolean use);
extern OPENMM_EXPORT double OpenMM_CustomNonbondedForce_getSwitchingDistance(const OpenMM_CustomNonbondedForce* target);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_setSwitchingDistance(OpenMM_CustomNonbondedForce* target, double distance);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_CustomNonbondedForce_getUseLongRangeCorrection(const OpenMM_CustomNonbondedForce* target);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_setUseLongRangeCorrection(OpenMM_CustomNonbondedForce* target, OpenMM_Boolean use);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_addPerParticleParameter(OpenMM_CustomNonbondedForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomNonbondedForce_getPerParticleParameterName(const OpenMM_CustomNonbondedForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_setPerParticleParameterName(OpenMM_CustomNonbondedForce* target, int index, const char* name);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_addGlobalParameter(OpenMM_CustomNonbondedForce* target, const char* name, double defaultValue);
extern OPENMM_EXPORT const char* OpenMM_CustomNonbondedForce_getGlobalParameterName(const OpenMM_CustomNonbondedForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_setGlobalParameterName(OpenMM_CustomNonbondedForce* target, int index, const char* name);
extern OPENMM_EXPORT double OpenMM_CustomNonbondedForce_getGlobalParameterDefaultValue(const OpenMM_CustomNonbondedForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_setGlobalParameterDefaultValue(OpenMM_CustomNonbondedForce* target, int index, double defaultValue);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_addEnergyParameterDerivative(OpenMM_CustomNonbondedForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomNonbondedForce_getEnergyParameterDerivativeName(const OpenMM_CustomNonbondedForce* target, int index);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_addParticle(OpenMM_CustomNonbondedForce* target, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_getParticleParameters(const OpenMM_CustomNonbondedForce* target, int index, OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_setParticleParameters(OpenMM_CustomNonbondedForce* target, int index, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_addExclusion(OpenMM_CustomNonbondedForce* target, int particle1, int particle2);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_getExclusionParticles(const OpenMM_CustomNonbondedForce* target, int index, int* particle1, int* particle2);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_setExclusionParticles(OpenMM_CustomNonbondedForce* target, int index, int particle1, int particle2);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_createExclusionsFromBonds(OpenMM_CustomNonbondedForce* target, const OpenMM_BondArray* bonds, int bondCutoff);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_addTabulatedFunction(OpenMM_CustomNonbondedForce* target, const char* name, OpenMM_TabulatedFunction* function);
extern OPENMM_EXPORT OpenMM_TabulatedFunction* OpenMM_CustomNonbondedForce_getTabulatedFunction(OpenMM_CustomNonbondedForce* target, int index);
extern OPENMM_EXPORT const char* OpenMM_CustomNonbondedForce_getTabulatedFunctionName(const OpenMM_CustomNonbondedForce* target, int index);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_addFunction(OpenMM_CustomNonbondedForce* target, const char* name, const OpenMM_DoubleArray* values, double min, double max);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_getFunctionParameters(const OpenMM_CustomNonbondedForce* target, int index, char** name, OpenMM_DoubleArray* values, double* min, double* max);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_setFunctionParameters(OpenMM_CustomNonbondedForce* target, int index, const char* name, const OpenMM_DoubleArray* values, double min, double max);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_addComputedValue(OpenMM_CustomNonbondedForce* target, const char* name, const char* expression);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_getComputedValueParameters(const OpenMM_CustomNonbondedForce* target, int index, char** name, char** expression);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_setComputedValueParameters(OpenMM_CustomNonbondedForce* target, int index, const char* name, const char* expression);
extern OPENMM_EXPORT int OpenMM_CustomNonbondedForce_addInteractionGroup(OpenMM_CustomNonbondedForce* target, const OpenMM_IntSet* set1, const OpenMM_IntSet* set2);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_getInteractionGroupParameters(const OpenMM_CustomNonbondedForce* target, int index, OpenMM_IntSet* set1, OpenMM_IntSet* set2);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_setInteractionGroupParameters(OpenMM_CustomNonbondedForce* target, int index, const OpenMM_IntSet* set1, const OpenMM_IntSet* set2);
extern OPENMM_EXPORT void OpenMM_CustomNonbondedForce_updateParametersInContext(OpenMM_CustomNonbondedForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_CustomNonbondedForce_usesPeriodicBoundaryConditions(const OpenMM_CustomNonbondedForce* target);

/* AndersenThermostat */
extern OPENMM_EXPORT OpenMM_AndersenThermostat* OpenMM_AndersenThermostat_create(double defaultTemperature, double defaultCollisionFrequency);
extern OPENMM_EXPORT void OpenMM_AndersenThermostat_destroy(OpenMM_AndersenThermostat* target);
extern OPENMM_EXPORT const char* OpenMM_AndersenThermostat_Temperature();
extern OPENMM_EXPORT const char* OpenMM_AndersenThermostat_CollisionFrequency();
extern OPENMM_EXPORT double OpenMM_AndersenThermostat_getDefaultTemperature(const OpenMM_AndersenThermostat* target);
extern OPENMM_EXPORT void OpenMM_AndersenThermostat_setDefaultTemperature(OpenMM_AndersenThermostat* target, double temperature);
extern OPENMM_EXPORT double OpenMM_AndersenThermostat_getDefaultCollisionFrequency(const OpenMM_AndersenThermostat* target);
extern OPENMM_EXPORT void OpenMM_AndersenThermostat_setDefaultCollisionFrequency(OpenMM_AndersenThermostat* target, double frequency);
extern OPENMM_EXPORT int OpenMM_AndersenThermostat_getRandomNumberSeed(const OpenMM_AndersenThermostat* target);
extern OPENMM_EXPORT void OpenMM_AndersenThermostat_setRandomNumberSeed(OpenMM_AndersenThermostat* target, int seed);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_AndersenThermostat_usesPeriodicBoundaryConditions(const OpenMM_AndersenThermostat* target);

/* VirtualSite */
extern OPENMM_EXPORT void OpenMM_VirtualSite_destroy(OpenMM_VirtualSite* target);
extern OPENMM_EXPORT int OpenMM_VirtualSite_getNumParticles(const OpenMM_VirtualSite* target);
extern OPENMM_EXPORT int OpenMM_VirtualSite_getParticle(const OpenMM_VirtualSite* target, int particle);

/* ThreeParticleAverageSite */
extern OPENMM_EXPORT OpenMM_ThreeParticleAverageSite* OpenMM_ThreeParticleAverageSite_create(int particle1, int particle2, int particle3, double weight1, double weight2, double weight3);
extern OPENMM_EXPORT void OpenMM_ThreeParticleAverageSite_destroy(OpenMM_ThreeParticleAverageSite* target);
extern OPENMM_EXPORT double OpenMM_ThreeParticleAverageSite_getWeight(const OpenMM_ThreeParticleAverageSite* target, int particle);

/* CustomHbondForce */
typedef enum {
  OpenMM_CustomHbondForce_NoCutoff = 0, OpenMM_CustomHbondForce_CutoffNonPeriodic = 1, OpenMM_CustomHbondForce_CutoffPeriodic = 2
} OpenMM_CustomHbondForce_NonbondedMethod;

extern OPENMM_EXPORT OpenMM_CustomHbondForce* OpenMM_CustomHbondForce_create(const char* energy);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_destroy(OpenMM_CustomHbondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomHbondForce_getNumDonors(const OpenMM_CustomHbondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomHbondForce_getNumAcceptors(const OpenMM_CustomHbondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomHbondForce_getNumExclusions(const OpenMM_CustomHbondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomHbondForce_getNumPerDonorParameters(const OpenMM_CustomHbondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomHbondForce_getNumPerAcceptorParameters(const OpenMM_CustomHbondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomHbondForce_getNumGlobalParameters(const OpenMM_CustomHbondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomHbondForce_getNumTabulatedFunctions(const OpenMM_CustomHbondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomHbondForce_getNumFunctions(const OpenMM_CustomHbondForce* target);
extern OPENMM_EXPORT const char* OpenMM_CustomHbondForce_getEnergyFunction(const OpenMM_CustomHbondForce* target);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_setEnergyFunction(OpenMM_CustomHbondForce* target, const char* energy);
extern OPENMM_EXPORT OpenMM_CustomHbondForce_NonbondedMethod OpenMM_CustomHbondForce_getNonbondedMethod(const OpenMM_CustomHbondForce* target);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_setNonbondedMethod(OpenMM_CustomHbondForce* target, OpenMM_CustomHbondForce_NonbondedMethod method);
extern OPENMM_EXPORT double OpenMM_CustomHbondForce_getCutoffDistance(const OpenMM_CustomHbondForce* target);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_setCutoffDistance(OpenMM_CustomHbondForce* target, double distance);
extern OPENMM_EXPORT int OpenMM_CustomHbondForce_addPerDonorParameter(OpenMM_CustomHbondForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomHbondForce_getPerDonorParameterName(const OpenMM_CustomHbondForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_setPerDonorParameterName(OpenMM_CustomHbondForce* target, int index, const char* name);
extern OPENMM_EXPORT int OpenMM_CustomHbondForce_addPerAcceptorParameter(OpenMM_CustomHbondForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomHbondForce_getPerAcceptorParameterName(const OpenMM_CustomHbondForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_setPerAcceptorParameterName(OpenMM_CustomHbondForce* target, int index, const char* name);
extern OPENMM_EXPORT int OpenMM_CustomHbondForce_addGlobalParameter(OpenMM_CustomHbondForce* target, const char* name, double defaultValue);
extern OPENMM_EXPORT const char* OpenMM_CustomHbondForce_getGlobalParameterName(const OpenMM_CustomHbondForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_setGlobalParameterName(OpenMM_CustomHbondForce* target, int index, const char* name);
extern OPENMM_EXPORT double OpenMM_CustomHbondForce_getGlobalParameterDefaultValue(const OpenMM_CustomHbondForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_setGlobalParameterDefaultValue(OpenMM_CustomHbondForce* target, int index, double defaultValue);
extern OPENMM_EXPORT int OpenMM_CustomHbondForce_addDonor(OpenMM_CustomHbondForce* target, int d1, int d2, int d3, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_getDonorParameters(const OpenMM_CustomHbondForce* target, int index, int* d1, int* d2, int* d3, OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_setDonorParameters(OpenMM_CustomHbondForce* target, int index, int d1, int d2, int d3, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT int OpenMM_CustomHbondForce_addAcceptor(OpenMM_CustomHbondForce* target, int a1, int a2, int a3, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_getAcceptorParameters(const OpenMM_CustomHbondForce* target, int index, int* a1, int* a2, int* a3, OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_setAcceptorParameters(OpenMM_CustomHbondForce* target, int index, int a1, int a2, int a3, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT int OpenMM_CustomHbondForce_addExclusion(OpenMM_CustomHbondForce* target, int donor, int acceptor);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_getExclusionParticles(const OpenMM_CustomHbondForce* target, int index, int* donor, int* acceptor);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_setExclusionParticles(OpenMM_CustomHbondForce* target, int index, int donor, int acceptor);
extern OPENMM_EXPORT int OpenMM_CustomHbondForce_addTabulatedFunction(OpenMM_CustomHbondForce* target, const char* name, OpenMM_TabulatedFunction* function);
extern OPENMM_EXPORT OpenMM_TabulatedFunction* OpenMM_CustomHbondForce_getTabulatedFunction(OpenMM_CustomHbondForce* target, int index);
extern OPENMM_EXPORT const char* OpenMM_CustomHbondForce_getTabulatedFunctionName(const OpenMM_CustomHbondForce* target, int index);
extern OPENMM_EXPORT int OpenMM_CustomHbondForce_addFunction(OpenMM_CustomHbondForce* target, const char* name, const OpenMM_DoubleArray* values, double min, double max);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_getFunctionParameters(const OpenMM_CustomHbondForce* target, int index, char** name, OpenMM_DoubleArray* values, double* min, double* max);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_setFunctionParameters(OpenMM_CustomHbondForce* target, int index, const char* name, const OpenMM_DoubleArray* values, double min, double max);
extern OPENMM_EXPORT void OpenMM_CustomHbondForce_updateParametersInContext(OpenMM_CustomHbondForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_CustomHbondForce_usesPeriodicBoundaryConditions(const OpenMM_CustomHbondForce* target);

/* Continuous1DFunction */
extern OPENMM_EXPORT OpenMM_Continuous1DFunction* OpenMM_Continuous1DFunction_create(const OpenMM_DoubleArray* values, double min, double max, OpenMM_Boolean periodic);
extern OPENMM_EXPORT void OpenMM_Continuous1DFunction_destroy(OpenMM_Continuous1DFunction* target);
extern OPENMM_EXPORT void OpenMM_Continuous1DFunction_getFunctionParameters(const OpenMM_Continuous1DFunction* target, OpenMM_DoubleArray* values, double* min, double* max);
extern OPENMM_EXPORT void OpenMM_Continuous1DFunction_setFunctionParameters(OpenMM_Continuous1DFunction* target, const OpenMM_DoubleArray* values, double min, double max);
extern OPENMM_EXPORT OpenMM_Continuous1DFunction* OpenMM_Continuous1DFunction_Copy(const OpenMM_Continuous1DFunction* target);

/* Discrete3DFunction */
extern OPENMM_EXPORT OpenMM_Discrete3DFunction* OpenMM_Discrete3DFunction_create(int xsize, int ysize, int zsize, const OpenMM_DoubleArray* values);
extern OPENMM_EXPORT void OpenMM_Discrete3DFunction_destroy(OpenMM_Discrete3DFunction* target);
extern OPENMM_EXPORT void OpenMM_Discrete3DFunction_getFunctionParameters(const OpenMM_Discrete3DFunction* target, int* xsize, int* ysize, int* zsize, OpenMM_DoubleArray* values);
extern OPENMM_EXPORT void OpenMM_Discrete3DFunction_setFunctionParameters(OpenMM_Discrete3DFunction* target, int xsize, int ysize, int zsize, const OpenMM_DoubleArray* values);
extern OPENMM_EXPORT OpenMM_Discrete3DFunction* OpenMM_Discrete3DFunction_Copy(const OpenMM_Discrete3DFunction* target);

/* OpenMMException */
extern OPENMM_EXPORT OpenMM_OpenMMException* OpenMM_OpenMMException_create(const char* message);
extern OPENMM_EXPORT void OpenMM_OpenMMException_destroy(OpenMM_OpenMMException* target);
extern OPENMM_EXPORT const char* OpenMM_OpenMMException_what(const OpenMM_OpenMMException* target);

/* MonteCarloFlexibleBarostat */
extern OPENMM_EXPORT OpenMM_MonteCarloFlexibleBarostat* OpenMM_MonteCarloFlexibleBarostat_create(double defaultPressure, double defaultTemperature, int frequency, OpenMM_Boolean scaleMoleculesAsRigid);
extern OPENMM_EXPORT void OpenMM_MonteCarloFlexibleBarostat_destroy(OpenMM_MonteCarloFlexibleBarostat* target);
extern OPENMM_EXPORT const char* OpenMM_MonteCarloFlexibleBarostat_Pressure();
extern OPENMM_EXPORT const char* OpenMM_MonteCarloFlexibleBarostat_Temperature();
extern OPENMM_EXPORT double OpenMM_MonteCarloFlexibleBarostat_getDefaultPressure(const OpenMM_MonteCarloFlexibleBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloFlexibleBarostat_setDefaultPressure(OpenMM_MonteCarloFlexibleBarostat* target, double pressure);
extern OPENMM_EXPORT int OpenMM_MonteCarloFlexibleBarostat_getFrequency(const OpenMM_MonteCarloFlexibleBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloFlexibleBarostat_setFrequency(OpenMM_MonteCarloFlexibleBarostat* target, int freq);
extern OPENMM_EXPORT double OpenMM_MonteCarloFlexibleBarostat_getDefaultTemperature(const OpenMM_MonteCarloFlexibleBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloFlexibleBarostat_setDefaultTemperature(OpenMM_MonteCarloFlexibleBarostat* target, double temp);
extern OPENMM_EXPORT int OpenMM_MonteCarloFlexibleBarostat_getRandomNumberSeed(const OpenMM_MonteCarloFlexibleBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloFlexibleBarostat_setRandomNumberSeed(OpenMM_MonteCarloFlexibleBarostat* target, int seed);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_MonteCarloFlexibleBarostat_usesPeriodicBoundaryConditions(const OpenMM_MonteCarloFlexibleBarostat* target);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_MonteCarloFlexibleBarostat_getScaleMoleculesAsRigid(const OpenMM_MonteCarloFlexibleBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloFlexibleBarostat_setScaleMoleculesAsRigid(OpenMM_MonteCarloFlexibleBarostat* target, OpenMM_Boolean rigid);

/* MonteCarloBarostat */
extern OPENMM_EXPORT OpenMM_MonteCarloBarostat* OpenMM_MonteCarloBarostat_create(double defaultPressure, double defaultTemperature, int frequency);
extern OPENMM_EXPORT void OpenMM_MonteCarloBarostat_destroy(OpenMM_MonteCarloBarostat* target);
extern OPENMM_EXPORT const char* OpenMM_MonteCarloBarostat_Pressure();
extern OPENMM_EXPORT const char* OpenMM_MonteCarloBarostat_Temperature();
extern OPENMM_EXPORT double OpenMM_MonteCarloBarostat_getDefaultPressure(const OpenMM_MonteCarloBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloBarostat_setDefaultPressure(OpenMM_MonteCarloBarostat* target, double pressure);
extern OPENMM_EXPORT int OpenMM_MonteCarloBarostat_getFrequency(const OpenMM_MonteCarloBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloBarostat_setFrequency(OpenMM_MonteCarloBarostat* target, int freq);
extern OPENMM_EXPORT double OpenMM_MonteCarloBarostat_getDefaultTemperature(const OpenMM_MonteCarloBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloBarostat_setDefaultTemperature(OpenMM_MonteCarloBarostat* target, double temp);
extern OPENMM_EXPORT int OpenMM_MonteCarloBarostat_getRandomNumberSeed(const OpenMM_MonteCarloBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloBarostat_setRandomNumberSeed(OpenMM_MonteCarloBarostat* target, int seed);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_MonteCarloBarostat_usesPeriodicBoundaryConditions(const OpenMM_MonteCarloBarostat* target);

/* GayBerneForce */
typedef enum {
  OpenMM_GayBerneForce_NoCutoff = 0, OpenMM_GayBerneForce_CutoffNonPeriodic = 1, OpenMM_GayBerneForce_CutoffPeriodic = 2
} OpenMM_GayBerneForce_NonbondedMethod;

extern OPENMM_EXPORT OpenMM_GayBerneForce* OpenMM_GayBerneForce_create();
extern OPENMM_EXPORT void OpenMM_GayBerneForce_destroy(OpenMM_GayBerneForce* target);
extern OPENMM_EXPORT int OpenMM_GayBerneForce_getNumParticles(const OpenMM_GayBerneForce* target);
extern OPENMM_EXPORT int OpenMM_GayBerneForce_getNumExceptions(const OpenMM_GayBerneForce* target);
extern OPENMM_EXPORT OpenMM_GayBerneForce_NonbondedMethod OpenMM_GayBerneForce_getNonbondedMethod(const OpenMM_GayBerneForce* target);
extern OPENMM_EXPORT void OpenMM_GayBerneForce_setNonbondedMethod(OpenMM_GayBerneForce* target, OpenMM_GayBerneForce_NonbondedMethod method);
extern OPENMM_EXPORT double OpenMM_GayBerneForce_getCutoffDistance(const OpenMM_GayBerneForce* target);
extern OPENMM_EXPORT void OpenMM_GayBerneForce_setCutoffDistance(OpenMM_GayBerneForce* target, double distance);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_GayBerneForce_getUseSwitchingFunction(const OpenMM_GayBerneForce* target);
extern OPENMM_EXPORT void OpenMM_GayBerneForce_setUseSwitchingFunction(OpenMM_GayBerneForce* target, OpenMM_Boolean use);
extern OPENMM_EXPORT double OpenMM_GayBerneForce_getSwitchingDistance(const OpenMM_GayBerneForce* target);
extern OPENMM_EXPORT void OpenMM_GayBerneForce_setSwitchingDistance(OpenMM_GayBerneForce* target, double distance);
extern OPENMM_EXPORT int OpenMM_GayBerneForce_addParticle(OpenMM_GayBerneForce* target, double sigma, double epsilon, int xparticle, int yparticle, double sx, double sy, double sz, double ex, double ey, double ez);
extern OPENMM_EXPORT void OpenMM_GayBerneForce_getParticleParameters(const OpenMM_GayBerneForce* target, int index, double* sigma, double* epsilon, int* xparticle, int* yparticle, double* sx, double* sy, double* sz, double* ex, double* ey, double* ez);
extern OPENMM_EXPORT void OpenMM_GayBerneForce_setParticleParameters(OpenMM_GayBerneForce* target, int index, double sigma, double epsilon, int xparticle, int yparticle, double sx, double sy, double sz, double ex, double ey, double ez);
extern OPENMM_EXPORT int OpenMM_GayBerneForce_addException(OpenMM_GayBerneForce* target, int particle1, int particle2, double sigma, double epsilon, OpenMM_Boolean replace);
extern OPENMM_EXPORT void OpenMM_GayBerneForce_getExceptionParameters(const OpenMM_GayBerneForce* target, int index, int* particle1, int* particle2, double* sigma, double* epsilon);
extern OPENMM_EXPORT void OpenMM_GayBerneForce_setExceptionParameters(OpenMM_GayBerneForce* target, int index, int particle1, int particle2, double sigma, double epsilon);
extern OPENMM_EXPORT void OpenMM_GayBerneForce_updateParametersInContext(OpenMM_GayBerneForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_GayBerneForce_usesPeriodicBoundaryConditions(const OpenMM_GayBerneForce* target);

/* TwoParticleAverageSite */
extern OPENMM_EXPORT OpenMM_TwoParticleAverageSite* OpenMM_TwoParticleAverageSite_create(int particle1, int particle2, double weight1, double weight2);
extern OPENMM_EXPORT void OpenMM_TwoParticleAverageSite_destroy(OpenMM_TwoParticleAverageSite* target);
extern OPENMM_EXPORT double OpenMM_TwoParticleAverageSite_getWeight(const OpenMM_TwoParticleAverageSite* target, int particle);

/* LocalCoordinatesSite */
extern OPENMM_EXPORT OpenMM_LocalCoordinatesSite* OpenMM_LocalCoordinatesSite_create(const OpenMM_IntArray* particles, const OpenMM_DoubleArray* originWeights, const OpenMM_DoubleArray* xWeights, const OpenMM_DoubleArray* yWeights, const OpenMM_Vec3* localPosition);
extern OPENMM_EXPORT OpenMM_LocalCoordinatesSite* OpenMM_LocalCoordinatesSite_create_2(int particle1, int particle2, int particle3, const OpenMM_Vec3* originWeights, const OpenMM_Vec3* xWeights, const OpenMM_Vec3* yWeights, const OpenMM_Vec3* localPosition);
extern OPENMM_EXPORT void OpenMM_LocalCoordinatesSite_destroy(OpenMM_LocalCoordinatesSite* target);
extern OPENMM_EXPORT void OpenMM_LocalCoordinatesSite_getOriginWeights(const OpenMM_LocalCoordinatesSite* target, OpenMM_DoubleArray* weights);
extern OPENMM_EXPORT void OpenMM_LocalCoordinatesSite_getXWeights(const OpenMM_LocalCoordinatesSite* target, OpenMM_DoubleArray* weights);
extern OPENMM_EXPORT void OpenMM_LocalCoordinatesSite_getYWeights(const OpenMM_LocalCoordinatesSite* target, OpenMM_DoubleArray* weights);
extern OPENMM_EXPORT const OpenMM_Vec3* OpenMM_LocalCoordinatesSite_getLocalPosition(const OpenMM_LocalCoordinatesSite* target);

/* CustomBondForce */
extern OPENMM_EXPORT OpenMM_CustomBondForce* OpenMM_CustomBondForce_create(const char* energy);
extern OPENMM_EXPORT void OpenMM_CustomBondForce_destroy(OpenMM_CustomBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomBondForce_getNumBonds(const OpenMM_CustomBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomBondForce_getNumPerBondParameters(const OpenMM_CustomBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomBondForce_getNumGlobalParameters(const OpenMM_CustomBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomBondForce_getNumEnergyParameterDerivatives(const OpenMM_CustomBondForce* target);
extern OPENMM_EXPORT const char* OpenMM_CustomBondForce_getEnergyFunction(const OpenMM_CustomBondForce* target);
extern OPENMM_EXPORT void OpenMM_CustomBondForce_setEnergyFunction(OpenMM_CustomBondForce* target, const char* energy);
extern OPENMM_EXPORT int OpenMM_CustomBondForce_addPerBondParameter(OpenMM_CustomBondForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomBondForce_getPerBondParameterName(const OpenMM_CustomBondForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomBondForce_setPerBondParameterName(OpenMM_CustomBondForce* target, int index, const char* name);
extern OPENMM_EXPORT int OpenMM_CustomBondForce_addGlobalParameter(OpenMM_CustomBondForce* target, const char* name, double defaultValue);
extern OPENMM_EXPORT const char* OpenMM_CustomBondForce_getGlobalParameterName(const OpenMM_CustomBondForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomBondForce_setGlobalParameterName(OpenMM_CustomBondForce* target, int index, const char* name);
extern OPENMM_EXPORT double OpenMM_CustomBondForce_getGlobalParameterDefaultValue(const OpenMM_CustomBondForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomBondForce_setGlobalParameterDefaultValue(OpenMM_CustomBondForce* target, int index, double defaultValue);
extern OPENMM_EXPORT void OpenMM_CustomBondForce_addEnergyParameterDerivative(OpenMM_CustomBondForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomBondForce_getEnergyParameterDerivativeName(const OpenMM_CustomBondForce* target, int index);
extern OPENMM_EXPORT int OpenMM_CustomBondForce_addBond(OpenMM_CustomBondForce* target, int particle1, int particle2, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomBondForce_getBondParameters(const OpenMM_CustomBondForce* target, int index, int* particle1, int* particle2, OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomBondForce_setBondParameters(OpenMM_CustomBondForce* target, int index, int particle1, int particle2, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomBondForce_updateParametersInContext(OpenMM_CustomBondForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT void OpenMM_CustomBondForce_setUsesPeriodicBoundaryConditions(OpenMM_CustomBondForce* target, OpenMM_Boolean periodic);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_CustomBondForce_usesPeriodicBoundaryConditions(const OpenMM_CustomBondForce* target);

/* State */
typedef enum {
  OpenMM_State_Positions = 1, OpenMM_State_Velocities = 2, OpenMM_State_Forces = 4, OpenMM_State_Energy = 8, OpenMM_State_Parameters = 16, OpenMM_State_ParameterDerivatives = 32, OpenMM_State_IntegratorParameters = 64
} OpenMM_State_DataType;

extern OPENMM_EXPORT OpenMM_State* OpenMM_State_create();
extern OPENMM_EXPORT void OpenMM_State_destroy(OpenMM_State* target);
extern OPENMM_EXPORT double OpenMM_State_getTime(const OpenMM_State* target);
extern OPENMM_EXPORT long long OpenMM_State_getStepCount(const OpenMM_State* target);
extern OPENMM_EXPORT const OpenMM_Vec3Array* OpenMM_State_getPositions(const OpenMM_State* target);
extern OPENMM_EXPORT const OpenMM_Vec3Array* OpenMM_State_getVelocities(const OpenMM_State* target);
extern OPENMM_EXPORT const OpenMM_Vec3Array* OpenMM_State_getForces(const OpenMM_State* target);
extern OPENMM_EXPORT double OpenMM_State_getKineticEnergy(const OpenMM_State* target);
extern OPENMM_EXPORT double OpenMM_State_getPotentialEnergy(const OpenMM_State* target);
extern OPENMM_EXPORT void OpenMM_State_getPeriodicBoxVectors(const OpenMM_State* target, OpenMM_Vec3* a, OpenMM_Vec3* b, OpenMM_Vec3* c);
extern OPENMM_EXPORT double OpenMM_State_getPeriodicBoxVolume(const OpenMM_State* target);
extern OPENMM_EXPORT const OpenMM_ParameterArray* OpenMM_State_getParameters(const OpenMM_State* target);
extern OPENMM_EXPORT const OpenMM_ParameterArray* OpenMM_State_getEnergyParameterDerivatives(const OpenMM_State* target);
extern OPENMM_EXPORT int OpenMM_State_getDataTypes(const OpenMM_State* target);

/* HarmonicAngleForce */
extern OPENMM_EXPORT OpenMM_HarmonicAngleForce* OpenMM_HarmonicAngleForce_create();
extern OPENMM_EXPORT void OpenMM_HarmonicAngleForce_destroy(OpenMM_HarmonicAngleForce* target);
extern OPENMM_EXPORT int OpenMM_HarmonicAngleForce_getNumAngles(const OpenMM_HarmonicAngleForce* target);
extern OPENMM_EXPORT int OpenMM_HarmonicAngleForce_addAngle(OpenMM_HarmonicAngleForce* target, int particle1, int particle2, int particle3, double angle, double k);
extern OPENMM_EXPORT void OpenMM_HarmonicAngleForce_getAngleParameters(const OpenMM_HarmonicAngleForce* target, int index, int* particle1, int* particle2, int* particle3, double* angle, double* k);
extern OPENMM_EXPORT void OpenMM_HarmonicAngleForce_setAngleParameters(OpenMM_HarmonicAngleForce* target, int index, int particle1, int particle2, int particle3, double angle, double k);
extern OPENMM_EXPORT void OpenMM_HarmonicAngleForce_updateParametersInContext(OpenMM_HarmonicAngleForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT void OpenMM_HarmonicAngleForce_setUsesPeriodicBoundaryConditions(OpenMM_HarmonicAngleForce* target, OpenMM_Boolean periodic);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_HarmonicAngleForce_usesPeriodicBoundaryConditions(const OpenMM_HarmonicAngleForce* target);

/* CustomManyParticleForce */
typedef enum {
  OpenMM_CustomManyParticleForce_NoCutoff = 0, OpenMM_CustomManyParticleForce_CutoffNonPeriodic = 1, OpenMM_CustomManyParticleForce_CutoffPeriodic = 2
} OpenMM_CustomManyParticleForce_NonbondedMethod;
typedef enum {
  OpenMM_CustomManyParticleForce_SinglePermutation = 0, OpenMM_CustomManyParticleForce_UniqueCentralParticle = 1
} OpenMM_CustomManyParticleForce_PermutationMode;

extern OPENMM_EXPORT OpenMM_CustomManyParticleForce* OpenMM_CustomManyParticleForce_create(int particlesPerSet, const char* energy);
extern OPENMM_EXPORT void OpenMM_CustomManyParticleForce_destroy(OpenMM_CustomManyParticleForce* target);
extern OPENMM_EXPORT int OpenMM_CustomManyParticleForce_getNumParticlesPerSet(const OpenMM_CustomManyParticleForce* target);
extern OPENMM_EXPORT int OpenMM_CustomManyParticleForce_getNumParticles(const OpenMM_CustomManyParticleForce* target);
extern OPENMM_EXPORT int OpenMM_CustomManyParticleForce_getNumExclusions(const OpenMM_CustomManyParticleForce* target);
extern OPENMM_EXPORT int OpenMM_CustomManyParticleForce_getNumPerParticleParameters(const OpenMM_CustomManyParticleForce* target);
extern OPENMM_EXPORT int OpenMM_CustomManyParticleForce_getNumGlobalParameters(const OpenMM_CustomManyParticleForce* target);
extern OPENMM_EXPORT int OpenMM_CustomManyParticleForce_getNumTabulatedFunctions(const OpenMM_CustomManyParticleForce* target);
extern OPENMM_EXPORT const char* OpenMM_CustomManyParticleForce_getEnergyFunction(const OpenMM_CustomManyParticleForce* target);
extern OPENMM_EXPORT void OpenMM_CustomManyParticleForce_setEnergyFunction(OpenMM_CustomManyParticleForce* target, const char* energy);
extern OPENMM_EXPORT OpenMM_CustomManyParticleForce_NonbondedMethod OpenMM_CustomManyParticleForce_getNonbondedMethod(const OpenMM_CustomManyParticleForce* target);
extern OPENMM_EXPORT void OpenMM_CustomManyParticleForce_setNonbondedMethod(OpenMM_CustomManyParticleForce* target, OpenMM_CustomManyParticleForce_NonbondedMethod method);
extern OPENMM_EXPORT OpenMM_CustomManyParticleForce_PermutationMode OpenMM_CustomManyParticleForce_getPermutationMode(const OpenMM_CustomManyParticleForce* target);
extern OPENMM_EXPORT void OpenMM_CustomManyParticleForce_setPermutationMode(OpenMM_CustomManyParticleForce* target, OpenMM_CustomManyParticleForce_PermutationMode mode);
extern OPENMM_EXPORT double OpenMM_CustomManyParticleForce_getCutoffDistance(const OpenMM_CustomManyParticleForce* target);
extern OPENMM_EXPORT void OpenMM_CustomManyParticleForce_setCutoffDistance(OpenMM_CustomManyParticleForce* target, double distance);
extern OPENMM_EXPORT int OpenMM_CustomManyParticleForce_addPerParticleParameter(OpenMM_CustomManyParticleForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomManyParticleForce_getPerParticleParameterName(const OpenMM_CustomManyParticleForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomManyParticleForce_setPerParticleParameterName(OpenMM_CustomManyParticleForce* target, int index, const char* name);
extern OPENMM_EXPORT int OpenMM_CustomManyParticleForce_addGlobalParameter(OpenMM_CustomManyParticleForce* target, const char* name, double defaultValue);
extern OPENMM_EXPORT const char* OpenMM_CustomManyParticleForce_getGlobalParameterName(const OpenMM_CustomManyParticleForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomManyParticleForce_setGlobalParameterName(OpenMM_CustomManyParticleForce* target, int index, const char* name);
extern OPENMM_EXPORT double OpenMM_CustomManyParticleForce_getGlobalParameterDefaultValue(const OpenMM_CustomManyParticleForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomManyParticleForce_setGlobalParameterDefaultValue(OpenMM_CustomManyParticleForce* target, int index, double defaultValue);
extern OPENMM_EXPORT int OpenMM_CustomManyParticleForce_addParticle(OpenMM_CustomManyParticleForce* target, const OpenMM_DoubleArray* parameters, int type);
extern OPENMM_EXPORT void OpenMM_CustomManyParticleForce_getParticleParameters(const OpenMM_CustomManyParticleForce* target, int index, OpenMM_DoubleArray* parameters, int* type);
extern OPENMM_EXPORT void OpenMM_CustomManyParticleForce_setParticleParameters(OpenMM_CustomManyParticleForce* target, int index, const OpenMM_DoubleArray* parameters, int type);
extern OPENMM_EXPORT int OpenMM_CustomManyParticleForce_addExclusion(OpenMM_CustomManyParticleForce* target, int particle1, int particle2);
extern OPENMM_EXPORT void OpenMM_CustomManyParticleForce_getExclusionParticles(const OpenMM_CustomManyParticleForce* target, int index, int* particle1, int* particle2);
extern OPENMM_EXPORT void OpenMM_CustomManyParticleForce_setExclusionParticles(OpenMM_CustomManyParticleForce* target, int index, int particle1, int particle2);
extern OPENMM_EXPORT void OpenMM_CustomManyParticleForce_createExclusionsFromBonds(OpenMM_CustomManyParticleForce* target, const OpenMM_BondArray* bonds, int bondCutoff);
extern OPENMM_EXPORT void OpenMM_CustomManyParticleForce_getTypeFilter(const OpenMM_CustomManyParticleForce* target, int index, OpenMM_IntSet* types);
extern OPENMM_EXPORT void OpenMM_CustomManyParticleForce_setTypeFilter(OpenMM_CustomManyParticleForce* target, int index, const OpenMM_IntSet* types);
extern OPENMM_EXPORT int OpenMM_CustomManyParticleForce_addTabulatedFunction(OpenMM_CustomManyParticleForce* target, const char* name, OpenMM_TabulatedFunction* function);
extern OPENMM_EXPORT OpenMM_TabulatedFunction* OpenMM_CustomManyParticleForce_getTabulatedFunction(OpenMM_CustomManyParticleForce* target, int index);
extern OPENMM_EXPORT const char* OpenMM_CustomManyParticleForce_getTabulatedFunctionName(const OpenMM_CustomManyParticleForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomManyParticleForce_updateParametersInContext(OpenMM_CustomManyParticleForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_CustomManyParticleForce_usesPeriodicBoundaryConditions(const OpenMM_CustomManyParticleForce* target);

/* Integrator */
extern OPENMM_EXPORT void OpenMM_Integrator_destroy(OpenMM_Integrator* target);
extern OPENMM_EXPORT double OpenMM_Integrator_getStepSize(const OpenMM_Integrator* target);
extern OPENMM_EXPORT void OpenMM_Integrator_setStepSize(OpenMM_Integrator* target, double size);
extern OPENMM_EXPORT double OpenMM_Integrator_getConstraintTolerance(const OpenMM_Integrator* target);
extern OPENMM_EXPORT void OpenMM_Integrator_setConstraintTolerance(OpenMM_Integrator* target, double tol);
extern OPENMM_EXPORT void OpenMM_Integrator_step(OpenMM_Integrator* target, int steps);
extern OPENMM_EXPORT int OpenMM_Integrator_getIntegrationForceGroups(const OpenMM_Integrator* target);
extern OPENMM_EXPORT void OpenMM_Integrator_setIntegrationForceGroups(OpenMM_Integrator* target, int groups);

/* VariableVerletIntegrator */
extern OPENMM_EXPORT OpenMM_VariableVerletIntegrator* OpenMM_VariableVerletIntegrator_create(double errorTol);
extern OPENMM_EXPORT void OpenMM_VariableVerletIntegrator_destroy(OpenMM_VariableVerletIntegrator* target);
extern OPENMM_EXPORT double OpenMM_VariableVerletIntegrator_getErrorTolerance(const OpenMM_VariableVerletIntegrator* target);
extern OPENMM_EXPORT void OpenMM_VariableVerletIntegrator_setErrorTolerance(OpenMM_VariableVerletIntegrator* target, double tol);
extern OPENMM_EXPORT double OpenMM_VariableVerletIntegrator_getMaximumStepSize(const OpenMM_VariableVerletIntegrator* target);
extern OPENMM_EXPORT void OpenMM_VariableVerletIntegrator_setMaximumStepSize(OpenMM_VariableVerletIntegrator* target, double size);
extern OPENMM_EXPORT void OpenMM_VariableVerletIntegrator_step(OpenMM_VariableVerletIntegrator* target, int steps);
extern OPENMM_EXPORT void OpenMM_VariableVerletIntegrator_stepTo(OpenMM_VariableVerletIntegrator* target, double time);

/* MonteCarloMembraneBarostat */
typedef enum {
  OpenMM_MonteCarloMembraneBarostat_XYIsotropic = 0, OpenMM_MonteCarloMembraneBarostat_XYAnisotropic = 1
} OpenMM_MonteCarloMembraneBarostat_XYMode;
typedef enum {
  OpenMM_MonteCarloMembraneBarostat_ZFree = 0, OpenMM_MonteCarloMembraneBarostat_ZFixed = 1, OpenMM_MonteCarloMembraneBarostat_ConstantVolume = 2
} OpenMM_MonteCarloMembraneBarostat_ZMode;

extern OPENMM_EXPORT OpenMM_MonteCarloMembraneBarostat* OpenMM_MonteCarloMembraneBarostat_create(double defaultPressure, double defaultSurfaceTension, double defaultTemperature, OpenMM_MonteCarloMembraneBarostat_XYMode xymode, OpenMM_MonteCarloMembraneBarostat_ZMode zmode, int frequency);
extern OPENMM_EXPORT void OpenMM_MonteCarloMembraneBarostat_destroy(OpenMM_MonteCarloMembraneBarostat* target);
extern OPENMM_EXPORT const char* OpenMM_MonteCarloMembraneBarostat_Pressure();
extern OPENMM_EXPORT const char* OpenMM_MonteCarloMembraneBarostat_SurfaceTension();
extern OPENMM_EXPORT const char* OpenMM_MonteCarloMembraneBarostat_Temperature();
extern OPENMM_EXPORT double OpenMM_MonteCarloMembraneBarostat_getDefaultPressure(const OpenMM_MonteCarloMembraneBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloMembraneBarostat_setDefaultPressure(OpenMM_MonteCarloMembraneBarostat* target, double pressure);
extern OPENMM_EXPORT double OpenMM_MonteCarloMembraneBarostat_getDefaultSurfaceTension(const OpenMM_MonteCarloMembraneBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloMembraneBarostat_setDefaultSurfaceTension(OpenMM_MonteCarloMembraneBarostat* target, double surfaceTension);
extern OPENMM_EXPORT int OpenMM_MonteCarloMembraneBarostat_getFrequency(const OpenMM_MonteCarloMembraneBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloMembraneBarostat_setFrequency(OpenMM_MonteCarloMembraneBarostat* target, int freq);
extern OPENMM_EXPORT double OpenMM_MonteCarloMembraneBarostat_getDefaultTemperature(const OpenMM_MonteCarloMembraneBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloMembraneBarostat_setDefaultTemperature(OpenMM_MonteCarloMembraneBarostat* target, double temp);
extern OPENMM_EXPORT OpenMM_MonteCarloMembraneBarostat_XYMode OpenMM_MonteCarloMembraneBarostat_getXYMode(const OpenMM_MonteCarloMembraneBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloMembraneBarostat_setXYMode(OpenMM_MonteCarloMembraneBarostat* target, OpenMM_MonteCarloMembraneBarostat_XYMode mode);
extern OPENMM_EXPORT OpenMM_MonteCarloMembraneBarostat_ZMode OpenMM_MonteCarloMembraneBarostat_getZMode(const OpenMM_MonteCarloMembraneBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloMembraneBarostat_setZMode(OpenMM_MonteCarloMembraneBarostat* target, OpenMM_MonteCarloMembraneBarostat_ZMode mode);
extern OPENMM_EXPORT int OpenMM_MonteCarloMembraneBarostat_getRandomNumberSeed(const OpenMM_MonteCarloMembraneBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloMembraneBarostat_setRandomNumberSeed(OpenMM_MonteCarloMembraneBarostat* target, int seed);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_MonteCarloMembraneBarostat_usesPeriodicBoundaryConditions(const OpenMM_MonteCarloMembraneBarostat* target);

/* MonteCarloAnisotropicBarostat */
extern OPENMM_EXPORT OpenMM_MonteCarloAnisotropicBarostat* OpenMM_MonteCarloAnisotropicBarostat_create(const OpenMM_Vec3* defaultPressure, double defaultTemperature, OpenMM_Boolean scaleX, OpenMM_Boolean scaleY, OpenMM_Boolean scaleZ, int frequency);
extern OPENMM_EXPORT void OpenMM_MonteCarloAnisotropicBarostat_destroy(OpenMM_MonteCarloAnisotropicBarostat* target);
extern OPENMM_EXPORT const char* OpenMM_MonteCarloAnisotropicBarostat_PressureX();
extern OPENMM_EXPORT const char* OpenMM_MonteCarloAnisotropicBarostat_PressureY();
extern OPENMM_EXPORT const char* OpenMM_MonteCarloAnisotropicBarostat_PressureZ();
extern OPENMM_EXPORT const char* OpenMM_MonteCarloAnisotropicBarostat_Temperature();
extern OPENMM_EXPORT const OpenMM_Vec3* OpenMM_MonteCarloAnisotropicBarostat_getDefaultPressure(const OpenMM_MonteCarloAnisotropicBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloAnisotropicBarostat_setDefaultPressure(OpenMM_MonteCarloAnisotropicBarostat* target, const OpenMM_Vec3* pressure);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_MonteCarloAnisotropicBarostat_getScaleX(const OpenMM_MonteCarloAnisotropicBarostat* target);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_MonteCarloAnisotropicBarostat_getScaleY(const OpenMM_MonteCarloAnisotropicBarostat* target);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_MonteCarloAnisotropicBarostat_getScaleZ(const OpenMM_MonteCarloAnisotropicBarostat* target);
extern OPENMM_EXPORT int OpenMM_MonteCarloAnisotropicBarostat_getFrequency(const OpenMM_MonteCarloAnisotropicBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloAnisotropicBarostat_setFrequency(OpenMM_MonteCarloAnisotropicBarostat* target, int freq);
extern OPENMM_EXPORT double OpenMM_MonteCarloAnisotropicBarostat_getDefaultTemperature(const OpenMM_MonteCarloAnisotropicBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloAnisotropicBarostat_setDefaultTemperature(OpenMM_MonteCarloAnisotropicBarostat* target, double temp);
extern OPENMM_EXPORT int OpenMM_MonteCarloAnisotropicBarostat_getRandomNumberSeed(const OpenMM_MonteCarloAnisotropicBarostat* target);
extern OPENMM_EXPORT void OpenMM_MonteCarloAnisotropicBarostat_setRandomNumberSeed(OpenMM_MonteCarloAnisotropicBarostat* target, int seed);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_MonteCarloAnisotropicBarostat_usesPeriodicBoundaryConditions(const OpenMM_MonteCarloAnisotropicBarostat* target);

/* NoseHooverIntegrator */
extern OPENMM_EXPORT OpenMM_NoseHooverIntegrator* OpenMM_NoseHooverIntegrator_create(double stepSize);
extern OPENMM_EXPORT OpenMM_NoseHooverIntegrator* OpenMM_NoseHooverIntegrator_create_2(double temperature, double collisionFrequency, double stepSize, int chainLength, int numMTS, int numYoshidaSuzuki);
extern OPENMM_EXPORT void OpenMM_NoseHooverIntegrator_destroy(OpenMM_NoseHooverIntegrator* target);
extern OPENMM_EXPORT void OpenMM_NoseHooverIntegrator_step(OpenMM_NoseHooverIntegrator* target, int steps);
extern OPENMM_EXPORT int OpenMM_NoseHooverIntegrator_addThermostat(OpenMM_NoseHooverIntegrator* target, double temperature, double collisionFrequency, int chainLength, int numMTS, int numYoshidaSuzuki);
extern OPENMM_EXPORT int OpenMM_NoseHooverIntegrator_addSubsystemThermostat(OpenMM_NoseHooverIntegrator* target, const OpenMM_IntArray* thermostatedParticles, const OpenMM_BondArray* thermostatedPairs, double temperature, double collisionFrequency, double relativeTemperature, double relativeCollisionFrequency, int chainLength, int numMTS, int numYoshidaSuzuki);
extern OPENMM_EXPORT double OpenMM_NoseHooverIntegrator_getTemperature(const OpenMM_NoseHooverIntegrator* target, int chainID);
extern OPENMM_EXPORT void OpenMM_NoseHooverIntegrator_setTemperature(OpenMM_NoseHooverIntegrator* target, double temperature, int chainID);
extern OPENMM_EXPORT double OpenMM_NoseHooverIntegrator_getRelativeTemperature(const OpenMM_NoseHooverIntegrator* target, int chainID);
extern OPENMM_EXPORT void OpenMM_NoseHooverIntegrator_setRelativeTemperature(OpenMM_NoseHooverIntegrator* target, double temperature, int chainID);
extern OPENMM_EXPORT double OpenMM_NoseHooverIntegrator_getCollisionFrequency(const OpenMM_NoseHooverIntegrator* target, int chainID);
extern OPENMM_EXPORT void OpenMM_NoseHooverIntegrator_setCollisionFrequency(OpenMM_NoseHooverIntegrator* target, double frequency, int chainID);
extern OPENMM_EXPORT double OpenMM_NoseHooverIntegrator_getRelativeCollisionFrequency(const OpenMM_NoseHooverIntegrator* target, int chainID);
extern OPENMM_EXPORT void OpenMM_NoseHooverIntegrator_setRelativeCollisionFrequency(OpenMM_NoseHooverIntegrator* target, double frequency, int chainID);
extern OPENMM_EXPORT double OpenMM_NoseHooverIntegrator_computeHeatBathEnergy(OpenMM_NoseHooverIntegrator* target);
extern OPENMM_EXPORT int OpenMM_NoseHooverIntegrator_getNumThermostats(const OpenMM_NoseHooverIntegrator* target);
extern OPENMM_EXPORT const OpenMM_NoseHooverChain* OpenMM_NoseHooverIntegrator_getThermostat(const OpenMM_NoseHooverIntegrator* target, int chainID);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_NoseHooverIntegrator_hasSubsystemThermostats(const OpenMM_NoseHooverIntegrator* target);
extern OPENMM_EXPORT double OpenMM_NoseHooverIntegrator_getMaximumPairDistance(const OpenMM_NoseHooverIntegrator* target);
extern OPENMM_EXPORT void OpenMM_NoseHooverIntegrator_setMaximumPairDistance(OpenMM_NoseHooverIntegrator* target, double distance);

/* CustomCVForce */
extern OPENMM_EXPORT OpenMM_CustomCVForce* OpenMM_CustomCVForce_create(const char* energy);
extern OPENMM_EXPORT void OpenMM_CustomCVForce_destroy(OpenMM_CustomCVForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCVForce_getNumCollectiveVariables(const OpenMM_CustomCVForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCVForce_getNumGlobalParameters(const OpenMM_CustomCVForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCVForce_getNumEnergyParameterDerivatives(const OpenMM_CustomCVForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCVForce_getNumTabulatedFunctions(const OpenMM_CustomCVForce* target);
extern OPENMM_EXPORT const char* OpenMM_CustomCVForce_getEnergyFunction(const OpenMM_CustomCVForce* target);
extern OPENMM_EXPORT void OpenMM_CustomCVForce_setEnergyFunction(OpenMM_CustomCVForce* target, const char* energy);
extern OPENMM_EXPORT int OpenMM_CustomCVForce_addCollectiveVariable(OpenMM_CustomCVForce* target, const char* name, OpenMM_Force* variable);
extern OPENMM_EXPORT const char* OpenMM_CustomCVForce_getCollectiveVariableName(const OpenMM_CustomCVForce* target, int index);
extern OPENMM_EXPORT OpenMM_Force* OpenMM_CustomCVForce_getCollectiveVariable(OpenMM_CustomCVForce* target, int index);
extern OPENMM_EXPORT int OpenMM_CustomCVForce_addGlobalParameter(OpenMM_CustomCVForce* target, const char* name, double defaultValue);
extern OPENMM_EXPORT const char* OpenMM_CustomCVForce_getGlobalParameterName(const OpenMM_CustomCVForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomCVForce_setGlobalParameterName(OpenMM_CustomCVForce* target, int index, const char* name);
extern OPENMM_EXPORT double OpenMM_CustomCVForce_getGlobalParameterDefaultValue(const OpenMM_CustomCVForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomCVForce_setGlobalParameterDefaultValue(OpenMM_CustomCVForce* target, int index, double defaultValue);
extern OPENMM_EXPORT void OpenMM_CustomCVForce_addEnergyParameterDerivative(OpenMM_CustomCVForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomCVForce_getEnergyParameterDerivativeName(const OpenMM_CustomCVForce* target, int index);
extern OPENMM_EXPORT int OpenMM_CustomCVForce_addTabulatedFunction(OpenMM_CustomCVForce* target, const char* name, OpenMM_TabulatedFunction* function);
extern OPENMM_EXPORT OpenMM_TabulatedFunction* OpenMM_CustomCVForce_getTabulatedFunction(OpenMM_CustomCVForce* target, int index);
extern OPENMM_EXPORT const char* OpenMM_CustomCVForce_getTabulatedFunctionName(const OpenMM_CustomCVForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomCVForce_getCollectiveVariableValues(const OpenMM_CustomCVForce* target, OpenMM_Context* context, OpenMM_DoubleArray* values);
extern OPENMM_EXPORT OpenMM_Context* OpenMM_CustomCVForce_getInnerContext(OpenMM_CustomCVForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT void OpenMM_CustomCVForce_updateParametersInContext(OpenMM_CustomCVForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_CustomCVForce_usesPeriodicBoundaryConditions(const OpenMM_CustomCVForce* target);

/* NonbondedForce */
typedef enum {
  OpenMM_NonbondedForce_NoCutoff = 0, OpenMM_NonbondedForce_CutoffNonPeriodic = 1, OpenMM_NonbondedForce_CutoffPeriodic = 2, OpenMM_NonbondedForce_Ewald = 3, OpenMM_NonbondedForce_PME = 4, OpenMM_NonbondedForce_LJPME = 5
} OpenMM_NonbondedForce_NonbondedMethod;

extern OPENMM_EXPORT OpenMM_NonbondedForce* OpenMM_NonbondedForce_create();
extern OPENMM_EXPORT void OpenMM_NonbondedForce_destroy(OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT int OpenMM_NonbondedForce_getNumParticles(const OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT int OpenMM_NonbondedForce_getNumExceptions(const OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT int OpenMM_NonbondedForce_getNumGlobalParameters(const OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT int OpenMM_NonbondedForce_getNumParticleParameterOffsets(const OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT int OpenMM_NonbondedForce_getNumExceptionParameterOffsets(const OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT OpenMM_NonbondedForce_NonbondedMethod OpenMM_NonbondedForce_getNonbondedMethod(const OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setNonbondedMethod(OpenMM_NonbondedForce* target, OpenMM_NonbondedForce_NonbondedMethod method);
extern OPENMM_EXPORT double OpenMM_NonbondedForce_getCutoffDistance(const OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setCutoffDistance(OpenMM_NonbondedForce* target, double distance);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_NonbondedForce_getUseSwitchingFunction(const OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setUseSwitchingFunction(OpenMM_NonbondedForce* target, OpenMM_Boolean use);
extern OPENMM_EXPORT double OpenMM_NonbondedForce_getSwitchingDistance(const OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setSwitchingDistance(OpenMM_NonbondedForce* target, double distance);
extern OPENMM_EXPORT double OpenMM_NonbondedForce_getReactionFieldDielectric(const OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setReactionFieldDielectric(OpenMM_NonbondedForce* target, double dielectric);
extern OPENMM_EXPORT double OpenMM_NonbondedForce_getEwaldErrorTolerance(const OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setEwaldErrorTolerance(OpenMM_NonbondedForce* target, double tol);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_getPMEParameters(const OpenMM_NonbondedForce* target, double* alpha, int* nx, int* ny, int* nz);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_getLJPMEParameters(const OpenMM_NonbondedForce* target, double* alpha, int* nx, int* ny, int* nz);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setPMEParameters(OpenMM_NonbondedForce* target, double alpha, int nx, int ny, int nz);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setLJPMEParameters(OpenMM_NonbondedForce* target, double alpha, int nx, int ny, int nz);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_getPMEParametersInContext(const OpenMM_NonbondedForce* target, const OpenMM_Context* context, double* alpha, int* nx, int* ny, int* nz);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_getLJPMEParametersInContext(const OpenMM_NonbondedForce* target, const OpenMM_Context* context, double* alpha, int* nx, int* ny, int* nz);
extern OPENMM_EXPORT int OpenMM_NonbondedForce_addParticle(OpenMM_NonbondedForce* target, double charge, double sigma, double epsilon);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_getParticleParameters(const OpenMM_NonbondedForce* target, int index, double* charge, double* sigma, double* epsilon);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setParticleParameters(OpenMM_NonbondedForce* target, int index, double charge, double sigma, double epsilon);
extern OPENMM_EXPORT int OpenMM_NonbondedForce_addException(OpenMM_NonbondedForce* target, int particle1, int particle2, double chargeProd, double sigma, double epsilon, OpenMM_Boolean replace);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_getExceptionParameters(const OpenMM_NonbondedForce* target, int index, int* particle1, int* particle2, double* chargeProd, double* sigma, double* epsilon);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setExceptionParameters(OpenMM_NonbondedForce* target, int index, int particle1, int particle2, double chargeProd, double sigma, double epsilon);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_createExceptionsFromBonds(OpenMM_NonbondedForce* target, const OpenMM_BondArray* bonds, double coulomb14Scale, double lj14Scale);
extern OPENMM_EXPORT int OpenMM_NonbondedForce_addGlobalParameter(OpenMM_NonbondedForce* target, const char* name, double defaultValue);
extern OPENMM_EXPORT const char* OpenMM_NonbondedForce_getGlobalParameterName(const OpenMM_NonbondedForce* target, int index);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setGlobalParameterName(OpenMM_NonbondedForce* target, int index, const char* name);
extern OPENMM_EXPORT double OpenMM_NonbondedForce_getGlobalParameterDefaultValue(const OpenMM_NonbondedForce* target, int index);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setGlobalParameterDefaultValue(OpenMM_NonbondedForce* target, int index, double defaultValue);
extern OPENMM_EXPORT int OpenMM_NonbondedForce_addParticleParameterOffset(OpenMM_NonbondedForce* target, const char* parameter, int particleIndex, double chargeScale, double sigmaScale, double epsilonScale);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_getParticleParameterOffset(const OpenMM_NonbondedForce* target, int index, char** parameter, int* particleIndex, double* chargeScale, double* sigmaScale, double* epsilonScale);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setParticleParameterOffset(OpenMM_NonbondedForce* target, int index, const char* parameter, int particleIndex, double chargeScale, double sigmaScale, double epsilonScale);
extern OPENMM_EXPORT int OpenMM_NonbondedForce_addExceptionParameterOffset(OpenMM_NonbondedForce* target, const char* parameter, int exceptionIndex, double chargeProdScale, double sigmaScale, double epsilonScale);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_getExceptionParameterOffset(const OpenMM_NonbondedForce* target, int index, char** parameter, int* exceptionIndex, double* chargeProdScale, double* sigmaScale, double* epsilonScale);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setExceptionParameterOffset(OpenMM_NonbondedForce* target, int index, const char* parameter, int exceptionIndex, double chargeProdScale, double sigmaScale, double epsilonScale);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_NonbondedForce_getUseDispersionCorrection(const OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setUseDispersionCorrection(OpenMM_NonbondedForce* target, OpenMM_Boolean useCorrection);
extern OPENMM_EXPORT int OpenMM_NonbondedForce_getReciprocalSpaceForceGroup(const OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setReciprocalSpaceForceGroup(OpenMM_NonbondedForce* target, int group);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_NonbondedForce_getIncludeDirectSpace(const OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setIncludeDirectSpace(OpenMM_NonbondedForce* target, OpenMM_Boolean include);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_updateParametersInContext(OpenMM_NonbondedForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_NonbondedForce_usesPeriodicBoundaryConditions(const OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_NonbondedForce_getExceptionsUsePeriodicBoundaryConditions(const OpenMM_NonbondedForce* target);
extern OPENMM_EXPORT void OpenMM_NonbondedForce_setExceptionsUsePeriodicBoundaryConditions(OpenMM_NonbondedForce* target, OpenMM_Boolean periodic);

/* PeriodicTorsionForce */
extern OPENMM_EXPORT OpenMM_PeriodicTorsionForce* OpenMM_PeriodicTorsionForce_create();
extern OPENMM_EXPORT void OpenMM_PeriodicTorsionForce_destroy(OpenMM_PeriodicTorsionForce* target);
extern OPENMM_EXPORT int OpenMM_PeriodicTorsionForce_getNumTorsions(const OpenMM_PeriodicTorsionForce* target);
extern OPENMM_EXPORT int OpenMM_PeriodicTorsionForce_addTorsion(OpenMM_PeriodicTorsionForce* target, int particle1, int particle2, int particle3, int particle4, int periodicity, double phase, double k);
extern OPENMM_EXPORT void OpenMM_PeriodicTorsionForce_getTorsionParameters(const OpenMM_PeriodicTorsionForce* target, int index, int* particle1, int* particle2, int* particle3, int* particle4, int* periodicity, double* phase, double* k);
extern OPENMM_EXPORT void OpenMM_PeriodicTorsionForce_setTorsionParameters(OpenMM_PeriodicTorsionForce* target, int index, int particle1, int particle2, int particle3, int particle4, int periodicity, double phase, double k);
extern OPENMM_EXPORT void OpenMM_PeriodicTorsionForce_updateParametersInContext(OpenMM_PeriodicTorsionForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT void OpenMM_PeriodicTorsionForce_setUsesPeriodicBoundaryConditions(OpenMM_PeriodicTorsionForce* target, OpenMM_Boolean periodic);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_PeriodicTorsionForce_usesPeriodicBoundaryConditions(const OpenMM_PeriodicTorsionForce* target);

/* BrownianIntegrator */
extern OPENMM_EXPORT OpenMM_BrownianIntegrator* OpenMM_BrownianIntegrator_create(double temperature, double frictionCoeff, double stepSize);
extern OPENMM_EXPORT void OpenMM_BrownianIntegrator_destroy(OpenMM_BrownianIntegrator* target);
extern OPENMM_EXPORT double OpenMM_BrownianIntegrator_getTemperature(const OpenMM_BrownianIntegrator* target);
extern OPENMM_EXPORT void OpenMM_BrownianIntegrator_setTemperature(OpenMM_BrownianIntegrator* target, double temp);
extern OPENMM_EXPORT double OpenMM_BrownianIntegrator_getFriction(const OpenMM_BrownianIntegrator* target);
extern OPENMM_EXPORT void OpenMM_BrownianIntegrator_setFriction(OpenMM_BrownianIntegrator* target, double coeff);
extern OPENMM_EXPORT int OpenMM_BrownianIntegrator_getRandomNumberSeed(const OpenMM_BrownianIntegrator* target);
extern OPENMM_EXPORT void OpenMM_BrownianIntegrator_setRandomNumberSeed(OpenMM_BrownianIntegrator* target, int seed);
extern OPENMM_EXPORT void OpenMM_BrownianIntegrator_step(OpenMM_BrownianIntegrator* target, int steps);

/* GBSAOBCForce */
typedef enum {
  OpenMM_GBSAOBCForce_NoCutoff = 0, OpenMM_GBSAOBCForce_CutoffNonPeriodic = 1, OpenMM_GBSAOBCForce_CutoffPeriodic = 2
} OpenMM_GBSAOBCForce_NonbondedMethod;

extern OPENMM_EXPORT OpenMM_GBSAOBCForce* OpenMM_GBSAOBCForce_create();
extern OPENMM_EXPORT void OpenMM_GBSAOBCForce_destroy(OpenMM_GBSAOBCForce* target);
extern OPENMM_EXPORT int OpenMM_GBSAOBCForce_getNumParticles(const OpenMM_GBSAOBCForce* target);
extern OPENMM_EXPORT int OpenMM_GBSAOBCForce_addParticle(OpenMM_GBSAOBCForce* target, double charge, double radius, double scalingFactor);
extern OPENMM_EXPORT void OpenMM_GBSAOBCForce_getParticleParameters(const OpenMM_GBSAOBCForce* target, int index, double* charge, double* radius, double* scalingFactor);
extern OPENMM_EXPORT void OpenMM_GBSAOBCForce_setParticleParameters(OpenMM_GBSAOBCForce* target, int index, double charge, double radius, double scalingFactor);
extern OPENMM_EXPORT double OpenMM_GBSAOBCForce_getSolventDielectric(const OpenMM_GBSAOBCForce* target);
extern OPENMM_EXPORT void OpenMM_GBSAOBCForce_setSolventDielectric(OpenMM_GBSAOBCForce* target, double dielectric);
extern OPENMM_EXPORT double OpenMM_GBSAOBCForce_getSoluteDielectric(const OpenMM_GBSAOBCForce* target);
extern OPENMM_EXPORT void OpenMM_GBSAOBCForce_setSoluteDielectric(OpenMM_GBSAOBCForce* target, double dielectric);
extern OPENMM_EXPORT double OpenMM_GBSAOBCForce_getSurfaceAreaEnergy(const OpenMM_GBSAOBCForce* target);
extern OPENMM_EXPORT void OpenMM_GBSAOBCForce_setSurfaceAreaEnergy(OpenMM_GBSAOBCForce* target, double energy);
extern OPENMM_EXPORT OpenMM_GBSAOBCForce_NonbondedMethod OpenMM_GBSAOBCForce_getNonbondedMethod(const OpenMM_GBSAOBCForce* target);
extern OPENMM_EXPORT void OpenMM_GBSAOBCForce_setNonbondedMethod(OpenMM_GBSAOBCForce* target, OpenMM_GBSAOBCForce_NonbondedMethod method);
extern OPENMM_EXPORT double OpenMM_GBSAOBCForce_getCutoffDistance(const OpenMM_GBSAOBCForce* target);
extern OPENMM_EXPORT void OpenMM_GBSAOBCForce_setCutoffDistance(OpenMM_GBSAOBCForce* target, double distance);
extern OPENMM_EXPORT void OpenMM_GBSAOBCForce_updateParametersInContext(OpenMM_GBSAOBCForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_GBSAOBCForce_usesPeriodicBoundaryConditions(const OpenMM_GBSAOBCForce* target);

/* VerletIntegrator */
extern OPENMM_EXPORT OpenMM_VerletIntegrator* OpenMM_VerletIntegrator_create(double stepSize);
extern OPENMM_EXPORT void OpenMM_VerletIntegrator_destroy(OpenMM_VerletIntegrator* target);
extern OPENMM_EXPORT void OpenMM_VerletIntegrator_step(OpenMM_VerletIntegrator* target, int steps);

/* NoseHooverChain */
extern OPENMM_EXPORT OpenMM_NoseHooverChain* OpenMM_NoseHooverChain_create(double temperature, double relativeTemperature, double collisionFrequency, double relativeCollisionFrequency, int numDOFs, int chainLength, int numMTS, int numYoshidaSuzuki, int chainID, const OpenMM_IntArray* thermostatedAtoms, const OpenMM_BondArray* thermostatedPairs);
extern OPENMM_EXPORT void OpenMM_NoseHooverChain_destroy(OpenMM_NoseHooverChain* target);
extern OPENMM_EXPORT double OpenMM_NoseHooverChain_getTemperature(const OpenMM_NoseHooverChain* target);
extern OPENMM_EXPORT void OpenMM_NoseHooverChain_setTemperature(OpenMM_NoseHooverChain* target, double temperature);
extern OPENMM_EXPORT double OpenMM_NoseHooverChain_getRelativeTemperature(const OpenMM_NoseHooverChain* target);
extern OPENMM_EXPORT void OpenMM_NoseHooverChain_setRelativeTemperature(OpenMM_NoseHooverChain* target, double temperature);
extern OPENMM_EXPORT double OpenMM_NoseHooverChain_getCollisionFrequency(const OpenMM_NoseHooverChain* target);
extern OPENMM_EXPORT void OpenMM_NoseHooverChain_setCollisionFrequency(OpenMM_NoseHooverChain* target, double frequency);
extern OPENMM_EXPORT double OpenMM_NoseHooverChain_getRelativeCollisionFrequency(const OpenMM_NoseHooverChain* target);
extern OPENMM_EXPORT void OpenMM_NoseHooverChain_setRelativeCollisionFrequency(OpenMM_NoseHooverChain* target, double frequency);
extern OPENMM_EXPORT int OpenMM_NoseHooverChain_getNumDegreesOfFreedom(const OpenMM_NoseHooverChain* target);
extern OPENMM_EXPORT void OpenMM_NoseHooverChain_setNumDegreesOfFreedom(OpenMM_NoseHooverChain* target, int numDOF);
extern OPENMM_EXPORT int OpenMM_NoseHooverChain_getChainLength(const OpenMM_NoseHooverChain* target);
extern OPENMM_EXPORT int OpenMM_NoseHooverChain_getNumMultiTimeSteps(const OpenMM_NoseHooverChain* target);
extern OPENMM_EXPORT int OpenMM_NoseHooverChain_getNumYoshidaSuzukiTimeSteps(const OpenMM_NoseHooverChain* target);
extern OPENMM_EXPORT int OpenMM_NoseHooverChain_getChainID(const OpenMM_NoseHooverChain* target);
extern OPENMM_EXPORT const OpenMM_IntArray* OpenMM_NoseHooverChain_getThermostatedAtoms(const OpenMM_NoseHooverChain* target);
extern OPENMM_EXPORT void OpenMM_NoseHooverChain_setThermostatedAtoms(OpenMM_NoseHooverChain* target, const OpenMM_IntArray* atomIDs);
extern OPENMM_EXPORT const OpenMM_BondArray* OpenMM_NoseHooverChain_getThermostatedPairs(const OpenMM_NoseHooverChain* target);
extern OPENMM_EXPORT void OpenMM_NoseHooverChain_setThermostatedPairs(OpenMM_NoseHooverChain* target, const OpenMM_BondArray* pairIDs);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_NoseHooverChain_usesPeriodicBoundaryConditions(const OpenMM_NoseHooverChain* target);

/* LangevinMiddleIntegrator */
extern OPENMM_EXPORT OpenMM_LangevinMiddleIntegrator* OpenMM_LangevinMiddleIntegrator_create(double temperature, double frictionCoeff, double stepSize);
extern OPENMM_EXPORT void OpenMM_LangevinMiddleIntegrator_destroy(OpenMM_LangevinMiddleIntegrator* target);
extern OPENMM_EXPORT double OpenMM_LangevinMiddleIntegrator_getTemperature(const OpenMM_LangevinMiddleIntegrator* target);
extern OPENMM_EXPORT void OpenMM_LangevinMiddleIntegrator_setTemperature(OpenMM_LangevinMiddleIntegrator* target, double temp);
extern OPENMM_EXPORT double OpenMM_LangevinMiddleIntegrator_getFriction(const OpenMM_LangevinMiddleIntegrator* target);
extern OPENMM_EXPORT void OpenMM_LangevinMiddleIntegrator_setFriction(OpenMM_LangevinMiddleIntegrator* target, double coeff);
extern OPENMM_EXPORT int OpenMM_LangevinMiddleIntegrator_getRandomNumberSeed(const OpenMM_LangevinMiddleIntegrator* target);
extern OPENMM_EXPORT void OpenMM_LangevinMiddleIntegrator_setRandomNumberSeed(OpenMM_LangevinMiddleIntegrator* target, int seed);
extern OPENMM_EXPORT void OpenMM_LangevinMiddleIntegrator_step(OpenMM_LangevinMiddleIntegrator* target, int steps);

/* LocalEnergyMinimizer */
extern OPENMM_EXPORT void OpenMM_LocalEnergyMinimizer_destroy(OpenMM_LocalEnergyMinimizer* target);
extern OPENMM_EXPORT void OpenMM_LocalEnergyMinimizer_minimize(OpenMM_Context* context, double tolerance, int maxIterations);

/* LangevinIntegrator */
extern OPENMM_EXPORT OpenMM_LangevinIntegrator* OpenMM_LangevinIntegrator_create(double temperature, double frictionCoeff, double stepSize);
extern OPENMM_EXPORT void OpenMM_LangevinIntegrator_destroy(OpenMM_LangevinIntegrator* target);
extern OPENMM_EXPORT double OpenMM_LangevinIntegrator_getTemperature(const OpenMM_LangevinIntegrator* target);
extern OPENMM_EXPORT void OpenMM_LangevinIntegrator_setTemperature(OpenMM_LangevinIntegrator* target, double temp);
extern OPENMM_EXPORT double OpenMM_LangevinIntegrator_getFriction(const OpenMM_LangevinIntegrator* target);
extern OPENMM_EXPORT void OpenMM_LangevinIntegrator_setFriction(OpenMM_LangevinIntegrator* target, double coeff);
extern OPENMM_EXPORT int OpenMM_LangevinIntegrator_getRandomNumberSeed(const OpenMM_LangevinIntegrator* target);
extern OPENMM_EXPORT void OpenMM_LangevinIntegrator_setRandomNumberSeed(OpenMM_LangevinIntegrator* target, int seed);
extern OPENMM_EXPORT void OpenMM_LangevinIntegrator_step(OpenMM_LangevinIntegrator* target, int steps);

/* VariableLangevinIntegrator */
extern OPENMM_EXPORT OpenMM_VariableLangevinIntegrator* OpenMM_VariableLangevinIntegrator_create(double temperature, double frictionCoeff, double errorTol);
extern OPENMM_EXPORT void OpenMM_VariableLangevinIntegrator_destroy(OpenMM_VariableLangevinIntegrator* target);
extern OPENMM_EXPORT double OpenMM_VariableLangevinIntegrator_getTemperature(const OpenMM_VariableLangevinIntegrator* target);
extern OPENMM_EXPORT void OpenMM_VariableLangevinIntegrator_setTemperature(OpenMM_VariableLangevinIntegrator* target, double temp);
extern OPENMM_EXPORT double OpenMM_VariableLangevinIntegrator_getFriction(const OpenMM_VariableLangevinIntegrator* target);
extern OPENMM_EXPORT void OpenMM_VariableLangevinIntegrator_setFriction(OpenMM_VariableLangevinIntegrator* target, double coeff);
extern OPENMM_EXPORT double OpenMM_VariableLangevinIntegrator_getErrorTolerance(const OpenMM_VariableLangevinIntegrator* target);
extern OPENMM_EXPORT void OpenMM_VariableLangevinIntegrator_setErrorTolerance(OpenMM_VariableLangevinIntegrator* target, double tol);
extern OPENMM_EXPORT double OpenMM_VariableLangevinIntegrator_getMaximumStepSize(const OpenMM_VariableLangevinIntegrator* target);
extern OPENMM_EXPORT void OpenMM_VariableLangevinIntegrator_setMaximumStepSize(OpenMM_VariableLangevinIntegrator* target, double size);
extern OPENMM_EXPORT int OpenMM_VariableLangevinIntegrator_getRandomNumberSeed(const OpenMM_VariableLangevinIntegrator* target);
extern OPENMM_EXPORT void OpenMM_VariableLangevinIntegrator_setRandomNumberSeed(OpenMM_VariableLangevinIntegrator* target, int seed);
extern OPENMM_EXPORT void OpenMM_VariableLangevinIntegrator_step(OpenMM_VariableLangevinIntegrator* target, int steps);
extern OPENMM_EXPORT void OpenMM_VariableLangevinIntegrator_stepTo(OpenMM_VariableLangevinIntegrator* target, double time);

/* CustomIntegrator */
typedef enum {
  OpenMM_CustomIntegrator_ComputeGlobal = 0, OpenMM_CustomIntegrator_ComputePerDof = 1, OpenMM_CustomIntegrator_ComputeSum = 2, OpenMM_CustomIntegrator_ConstrainPositions = 3, OpenMM_CustomIntegrator_ConstrainVelocities = 4, OpenMM_CustomIntegrator_UpdateContextState = 5, OpenMM_CustomIntegrator_IfBlockStart = 6, OpenMM_CustomIntegrator_WhileBlockStart = 7, OpenMM_CustomIntegrator_BlockEnd = 8
} OpenMM_CustomIntegrator_ComputationType;

extern OPENMM_EXPORT OpenMM_CustomIntegrator* OpenMM_CustomIntegrator_create(double stepSize);
extern OPENMM_EXPORT void OpenMM_CustomIntegrator_destroy(OpenMM_CustomIntegrator* target);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_getNumGlobalVariables(const OpenMM_CustomIntegrator* target);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_getNumPerDofVariables(const OpenMM_CustomIntegrator* target);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_getNumComputations(const OpenMM_CustomIntegrator* target);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_getNumTabulatedFunctions(const OpenMM_CustomIntegrator* target);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_addGlobalVariable(OpenMM_CustomIntegrator* target, const char* name, double initialValue);
extern OPENMM_EXPORT const char* OpenMM_CustomIntegrator_getGlobalVariableName(const OpenMM_CustomIntegrator* target, int index);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_addPerDofVariable(OpenMM_CustomIntegrator* target, const char* name, double initialValue);
extern OPENMM_EXPORT const char* OpenMM_CustomIntegrator_getPerDofVariableName(const OpenMM_CustomIntegrator* target, int index);
extern OPENMM_EXPORT double OpenMM_CustomIntegrator_getGlobalVariable(const OpenMM_CustomIntegrator* target, int index);
extern OPENMM_EXPORT double OpenMM_CustomIntegrator_getGlobalVariableByName(const OpenMM_CustomIntegrator* target, const char* name);
extern OPENMM_EXPORT void OpenMM_CustomIntegrator_setGlobalVariable(OpenMM_CustomIntegrator* target, int index, double value);
extern OPENMM_EXPORT void OpenMM_CustomIntegrator_setGlobalVariableByName(OpenMM_CustomIntegrator* target, const char* name, double value);
extern OPENMM_EXPORT void OpenMM_CustomIntegrator_getPerDofVariable(const OpenMM_CustomIntegrator* target, int index, OpenMM_Vec3Array* values);
extern OPENMM_EXPORT void OpenMM_CustomIntegrator_getPerDofVariableByName(const OpenMM_CustomIntegrator* target, const char* name, OpenMM_Vec3Array* values);
extern OPENMM_EXPORT void OpenMM_CustomIntegrator_setPerDofVariable(OpenMM_CustomIntegrator* target, int index, const OpenMM_Vec3Array* values);
extern OPENMM_EXPORT void OpenMM_CustomIntegrator_setPerDofVariableByName(OpenMM_CustomIntegrator* target, const char* name, const OpenMM_Vec3Array* values);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_addComputeGlobal(OpenMM_CustomIntegrator* target, const char* variable, const char* expression);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_addComputePerDof(OpenMM_CustomIntegrator* target, const char* variable, const char* expression);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_addComputeSum(OpenMM_CustomIntegrator* target, const char* variable, const char* expression);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_addConstrainPositions(OpenMM_CustomIntegrator* target);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_addConstrainVelocities(OpenMM_CustomIntegrator* target);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_addUpdateContextState(OpenMM_CustomIntegrator* target);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_beginIfBlock(OpenMM_CustomIntegrator* target, const char* condition);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_beginWhileBlock(OpenMM_CustomIntegrator* target, const char* condition);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_endBlock(OpenMM_CustomIntegrator* target);
extern OPENMM_EXPORT void OpenMM_CustomIntegrator_getComputationStep(const OpenMM_CustomIntegrator* target, int index, OpenMM_CustomIntegrator_ComputationType* type, char** variable, char** expression);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_addTabulatedFunction(OpenMM_CustomIntegrator* target, const char* name, OpenMM_TabulatedFunction* function);
extern OPENMM_EXPORT OpenMM_TabulatedFunction* OpenMM_CustomIntegrator_getTabulatedFunction(OpenMM_CustomIntegrator* target, int index);
extern OPENMM_EXPORT const char* OpenMM_CustomIntegrator_getTabulatedFunctionName(const OpenMM_CustomIntegrator* target, int index);
extern OPENMM_EXPORT const char* OpenMM_CustomIntegrator_getKineticEnergyExpression(const OpenMM_CustomIntegrator* target);
extern OPENMM_EXPORT void OpenMM_CustomIntegrator_setKineticEnergyExpression(OpenMM_CustomIntegrator* target, const char* expression);
extern OPENMM_EXPORT int OpenMM_CustomIntegrator_getRandomNumberSeed(const OpenMM_CustomIntegrator* target);
extern OPENMM_EXPORT void OpenMM_CustomIntegrator_setRandomNumberSeed(OpenMM_CustomIntegrator* target, int seed);
extern OPENMM_EXPORT void OpenMM_CustomIntegrator_step(OpenMM_CustomIntegrator* target, int steps);

/* RBTorsionForce */
extern OPENMM_EXPORT OpenMM_RBTorsionForce* OpenMM_RBTorsionForce_create();
extern OPENMM_EXPORT void OpenMM_RBTorsionForce_destroy(OpenMM_RBTorsionForce* target);
extern OPENMM_EXPORT int OpenMM_RBTorsionForce_getNumTorsions(const OpenMM_RBTorsionForce* target);
extern OPENMM_EXPORT int OpenMM_RBTorsionForce_addTorsion(OpenMM_RBTorsionForce* target, int particle1, int particle2, int particle3, int particle4, double c0, double c1, double c2, double c3, double c4, double c5);
extern OPENMM_EXPORT void OpenMM_RBTorsionForce_getTorsionParameters(const OpenMM_RBTorsionForce* target, int index, int* particle1, int* particle2, int* particle3, int* particle4, double* c0, double* c1, double* c2, double* c3, double* c4, double* c5);
extern OPENMM_EXPORT void OpenMM_RBTorsionForce_setTorsionParameters(OpenMM_RBTorsionForce* target, int index, int particle1, int particle2, int particle3, int particle4, double c0, double c1, double c2, double c3, double c4, double c5);
extern OPENMM_EXPORT void OpenMM_RBTorsionForce_updateParametersInContext(OpenMM_RBTorsionForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT void OpenMM_RBTorsionForce_setUsesPeriodicBoundaryConditions(OpenMM_RBTorsionForce* target, OpenMM_Boolean periodic);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_RBTorsionForce_usesPeriodicBoundaryConditions(const OpenMM_RBTorsionForce* target);

/* CompoundIntegrator */
extern OPENMM_EXPORT OpenMM_CompoundIntegrator* OpenMM_CompoundIntegrator_create();
extern OPENMM_EXPORT void OpenMM_CompoundIntegrator_destroy(OpenMM_CompoundIntegrator* target);
extern OPENMM_EXPORT int OpenMM_CompoundIntegrator_getNumIntegrators(const OpenMM_CompoundIntegrator* target);
extern OPENMM_EXPORT int OpenMM_CompoundIntegrator_addIntegrator(OpenMM_CompoundIntegrator* target, OpenMM_Integrator* integrator);
extern OPENMM_EXPORT OpenMM_Integrator* OpenMM_CompoundIntegrator_getIntegrator(OpenMM_CompoundIntegrator* target, int index);
extern OPENMM_EXPORT int OpenMM_CompoundIntegrator_getCurrentIntegrator(const OpenMM_CompoundIntegrator* target);
extern OPENMM_EXPORT void OpenMM_CompoundIntegrator_setCurrentIntegrator(OpenMM_CompoundIntegrator* target, int index);
extern OPENMM_EXPORT double OpenMM_CompoundIntegrator_getStepSize(const OpenMM_CompoundIntegrator* target);
extern OPENMM_EXPORT void OpenMM_CompoundIntegrator_setStepSize(OpenMM_CompoundIntegrator* target, double size);
extern OPENMM_EXPORT double OpenMM_CompoundIntegrator_getConstraintTolerance(const OpenMM_CompoundIntegrator* target);
extern OPENMM_EXPORT void OpenMM_CompoundIntegrator_setConstraintTolerance(OpenMM_CompoundIntegrator* target, double tol);
extern OPENMM_EXPORT void OpenMM_CompoundIntegrator_step(OpenMM_CompoundIntegrator* target, int steps);

/* System */
extern OPENMM_EXPORT OpenMM_System* OpenMM_System_create();
extern OPENMM_EXPORT void OpenMM_System_destroy(OpenMM_System* target);
extern OPENMM_EXPORT int OpenMM_System_getNumParticles(const OpenMM_System* target);
extern OPENMM_EXPORT int OpenMM_System_addParticle(OpenMM_System* target, double mass);
extern OPENMM_EXPORT double OpenMM_System_getParticleMass(const OpenMM_System* target, int index);
extern OPENMM_EXPORT void OpenMM_System_setParticleMass(OpenMM_System* target, int index, double mass);
extern OPENMM_EXPORT void OpenMM_System_setVirtualSite(OpenMM_System* target, int index, OpenMM_VirtualSite* virtualSite);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_System_isVirtualSite(const OpenMM_System* target, int index);
extern OPENMM_EXPORT const OpenMM_VirtualSite* OpenMM_System_getVirtualSite(const OpenMM_System* target, int index);
extern OPENMM_EXPORT int OpenMM_System_getNumConstraints(const OpenMM_System* target);
extern OPENMM_EXPORT int OpenMM_System_addConstraint(OpenMM_System* target, int particle1, int particle2, double distance);
extern OPENMM_EXPORT void OpenMM_System_getConstraintParameters(const OpenMM_System* target, int index, int* particle1, int* particle2, double* distance);
extern OPENMM_EXPORT void OpenMM_System_setConstraintParameters(OpenMM_System* target, int index, int particle1, int particle2, double distance);
extern OPENMM_EXPORT void OpenMM_System_removeConstraint(OpenMM_System* target, int index);
extern OPENMM_EXPORT int OpenMM_System_addForce(OpenMM_System* target, OpenMM_Force* force);
extern OPENMM_EXPORT int OpenMM_System_getNumForces(const OpenMM_System* target);
extern OPENMM_EXPORT OpenMM_Force* OpenMM_System_getForce(OpenMM_System* target, int index);
extern OPENMM_EXPORT void OpenMM_System_removeForce(OpenMM_System* target, int index);
extern OPENMM_EXPORT void OpenMM_System_getDefaultPeriodicBoxVectors(const OpenMM_System* target, OpenMM_Vec3* a, OpenMM_Vec3* b, OpenMM_Vec3* c);
extern OPENMM_EXPORT void OpenMM_System_setDefaultPeriodicBoxVectors(OpenMM_System* target, const OpenMM_Vec3* a, const OpenMM_Vec3* b, const OpenMM_Vec3* c);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_System_usesPeriodicBoundaryConditions(const OpenMM_System* target);

/* CustomCompoundBondForce */
extern OPENMM_EXPORT OpenMM_CustomCompoundBondForce* OpenMM_CustomCompoundBondForce_create(int numParticles, const char* energy);
extern OPENMM_EXPORT void OpenMM_CustomCompoundBondForce_destroy(OpenMM_CustomCompoundBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCompoundBondForce_getNumParticlesPerBond(const OpenMM_CustomCompoundBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCompoundBondForce_getNumBonds(const OpenMM_CustomCompoundBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCompoundBondForce_getNumPerBondParameters(const OpenMM_CustomCompoundBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCompoundBondForce_getNumGlobalParameters(const OpenMM_CustomCompoundBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCompoundBondForce_getNumEnergyParameterDerivatives(const OpenMM_CustomCompoundBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCompoundBondForce_getNumTabulatedFunctions(const OpenMM_CustomCompoundBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCompoundBondForce_getNumFunctions(const OpenMM_CustomCompoundBondForce* target);
extern OPENMM_EXPORT const char* OpenMM_CustomCompoundBondForce_getEnergyFunction(const OpenMM_CustomCompoundBondForce* target);
extern OPENMM_EXPORT void OpenMM_CustomCompoundBondForce_setEnergyFunction(OpenMM_CustomCompoundBondForce* target, const char* energy);
extern OPENMM_EXPORT int OpenMM_CustomCompoundBondForce_addPerBondParameter(OpenMM_CustomCompoundBondForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomCompoundBondForce_getPerBondParameterName(const OpenMM_CustomCompoundBondForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomCompoundBondForce_setPerBondParameterName(OpenMM_CustomCompoundBondForce* target, int index, const char* name);
extern OPENMM_EXPORT int OpenMM_CustomCompoundBondForce_addGlobalParameter(OpenMM_CustomCompoundBondForce* target, const char* name, double defaultValue);
extern OPENMM_EXPORT const char* OpenMM_CustomCompoundBondForce_getGlobalParameterName(const OpenMM_CustomCompoundBondForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomCompoundBondForce_setGlobalParameterName(OpenMM_CustomCompoundBondForce* target, int index, const char* name);
extern OPENMM_EXPORT double OpenMM_CustomCompoundBondForce_getGlobalParameterDefaultValue(const OpenMM_CustomCompoundBondForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomCompoundBondForce_setGlobalParameterDefaultValue(OpenMM_CustomCompoundBondForce* target, int index, double defaultValue);
extern OPENMM_EXPORT void OpenMM_CustomCompoundBondForce_addEnergyParameterDerivative(OpenMM_CustomCompoundBondForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomCompoundBondForce_getEnergyParameterDerivativeName(const OpenMM_CustomCompoundBondForce* target, int index);
extern OPENMM_EXPORT int OpenMM_CustomCompoundBondForce_addBond(OpenMM_CustomCompoundBondForce* target, const OpenMM_IntArray* particles, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomCompoundBondForce_getBondParameters(const OpenMM_CustomCompoundBondForce* target, int index, OpenMM_IntArray* particles, OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomCompoundBondForce_setBondParameters(OpenMM_CustomCompoundBondForce* target, int index, const OpenMM_IntArray* particles, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT int OpenMM_CustomCompoundBondForce_addTabulatedFunction(OpenMM_CustomCompoundBondForce* target, const char* name, OpenMM_TabulatedFunction* function);
extern OPENMM_EXPORT OpenMM_TabulatedFunction* OpenMM_CustomCompoundBondForce_getTabulatedFunction(OpenMM_CustomCompoundBondForce* target, int index);
extern OPENMM_EXPORT const char* OpenMM_CustomCompoundBondForce_getTabulatedFunctionName(const OpenMM_CustomCompoundBondForce* target, int index);
extern OPENMM_EXPORT int OpenMM_CustomCompoundBondForce_addFunction(OpenMM_CustomCompoundBondForce* target, const char* name, const OpenMM_DoubleArray* values, double min, double max);
extern OPENMM_EXPORT void OpenMM_CustomCompoundBondForce_getFunctionParameters(const OpenMM_CustomCompoundBondForce* target, int index, char** name, OpenMM_DoubleArray* values, double* min, double* max);
extern OPENMM_EXPORT void OpenMM_CustomCompoundBondForce_setFunctionParameters(OpenMM_CustomCompoundBondForce* target, int index, const char* name, const OpenMM_DoubleArray* values, double min, double max);
extern OPENMM_EXPORT void OpenMM_CustomCompoundBondForce_updateParametersInContext(OpenMM_CustomCompoundBondForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT void OpenMM_CustomCompoundBondForce_setUsesPeriodicBoundaryConditions(OpenMM_CustomCompoundBondForce* target, OpenMM_Boolean periodic);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_CustomCompoundBondForce_usesPeriodicBoundaryConditions(const OpenMM_CustomCompoundBondForce* target);

/* CustomCentroidBondForce */
extern OPENMM_EXPORT OpenMM_CustomCentroidBondForce* OpenMM_CustomCentroidBondForce_create(int numGroups, const char* energy);
extern OPENMM_EXPORT void OpenMM_CustomCentroidBondForce_destroy(OpenMM_CustomCentroidBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCentroidBondForce_getNumGroupsPerBond(const OpenMM_CustomCentroidBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCentroidBondForce_getNumGroups(const OpenMM_CustomCentroidBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCentroidBondForce_getNumBonds(const OpenMM_CustomCentroidBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCentroidBondForce_getNumPerBondParameters(const OpenMM_CustomCentroidBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCentroidBondForce_getNumGlobalParameters(const OpenMM_CustomCentroidBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCentroidBondForce_getNumEnergyParameterDerivatives(const OpenMM_CustomCentroidBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCentroidBondForce_getNumTabulatedFunctions(const OpenMM_CustomCentroidBondForce* target);
extern OPENMM_EXPORT int OpenMM_CustomCentroidBondForce_getNumFunctions(const OpenMM_CustomCentroidBondForce* target);
extern OPENMM_EXPORT const char* OpenMM_CustomCentroidBondForce_getEnergyFunction(const OpenMM_CustomCentroidBondForce* target);
extern OPENMM_EXPORT void OpenMM_CustomCentroidBondForce_setEnergyFunction(OpenMM_CustomCentroidBondForce* target, const char* energy);
extern OPENMM_EXPORT int OpenMM_CustomCentroidBondForce_addPerBondParameter(OpenMM_CustomCentroidBondForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomCentroidBondForce_getPerBondParameterName(const OpenMM_CustomCentroidBondForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomCentroidBondForce_setPerBondParameterName(OpenMM_CustomCentroidBondForce* target, int index, const char* name);
extern OPENMM_EXPORT int OpenMM_CustomCentroidBondForce_addGlobalParameter(OpenMM_CustomCentroidBondForce* target, const char* name, double defaultValue);
extern OPENMM_EXPORT const char* OpenMM_CustomCentroidBondForce_getGlobalParameterName(const OpenMM_CustomCentroidBondForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomCentroidBondForce_setGlobalParameterName(OpenMM_CustomCentroidBondForce* target, int index, const char* name);
extern OPENMM_EXPORT double OpenMM_CustomCentroidBondForce_getGlobalParameterDefaultValue(const OpenMM_CustomCentroidBondForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomCentroidBondForce_setGlobalParameterDefaultValue(OpenMM_CustomCentroidBondForce* target, int index, double defaultValue);
extern OPENMM_EXPORT void OpenMM_CustomCentroidBondForce_addEnergyParameterDerivative(OpenMM_CustomCentroidBondForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomCentroidBondForce_getEnergyParameterDerivativeName(const OpenMM_CustomCentroidBondForce* target, int index);
extern OPENMM_EXPORT int OpenMM_CustomCentroidBondForce_addGroup(OpenMM_CustomCentroidBondForce* target, const OpenMM_IntArray* particles, const OpenMM_DoubleArray* weights);
extern OPENMM_EXPORT void OpenMM_CustomCentroidBondForce_getGroupParameters(const OpenMM_CustomCentroidBondForce* target, int index, OpenMM_IntArray* particles, OpenMM_DoubleArray* weights);
extern OPENMM_EXPORT void OpenMM_CustomCentroidBondForce_setGroupParameters(OpenMM_CustomCentroidBondForce* target, int index, const OpenMM_IntArray* particles, const OpenMM_DoubleArray* weights);
extern OPENMM_EXPORT int OpenMM_CustomCentroidBondForce_addBond(OpenMM_CustomCentroidBondForce* target, const OpenMM_IntArray* groups, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomCentroidBondForce_getBondParameters(const OpenMM_CustomCentroidBondForce* target, int index, OpenMM_IntArray* groups, OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomCentroidBondForce_setBondParameters(OpenMM_CustomCentroidBondForce* target, int index, const OpenMM_IntArray* groups, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT int OpenMM_CustomCentroidBondForce_addTabulatedFunction(OpenMM_CustomCentroidBondForce* target, const char* name, OpenMM_TabulatedFunction* function);
extern OPENMM_EXPORT OpenMM_TabulatedFunction* OpenMM_CustomCentroidBondForce_getTabulatedFunction(OpenMM_CustomCentroidBondForce* target, int index);
extern OPENMM_EXPORT const char* OpenMM_CustomCentroidBondForce_getTabulatedFunctionName(const OpenMM_CustomCentroidBondForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomCentroidBondForce_updateParametersInContext(OpenMM_CustomCentroidBondForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT void OpenMM_CustomCentroidBondForce_setUsesPeriodicBoundaryConditions(OpenMM_CustomCentroidBondForce* target, OpenMM_Boolean periodic);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_CustomCentroidBondForce_usesPeriodicBoundaryConditions(const OpenMM_CustomCentroidBondForce* target);

/* CMAPTorsionForce */
extern OPENMM_EXPORT OpenMM_CMAPTorsionForce* OpenMM_CMAPTorsionForce_create();
extern OPENMM_EXPORT void OpenMM_CMAPTorsionForce_destroy(OpenMM_CMAPTorsionForce* target);
extern OPENMM_EXPORT int OpenMM_CMAPTorsionForce_getNumMaps(const OpenMM_CMAPTorsionForce* target);
extern OPENMM_EXPORT int OpenMM_CMAPTorsionForce_getNumTorsions(const OpenMM_CMAPTorsionForce* target);
extern OPENMM_EXPORT int OpenMM_CMAPTorsionForce_addMap(OpenMM_CMAPTorsionForce* target, int size, const OpenMM_DoubleArray* energy);
extern OPENMM_EXPORT void OpenMM_CMAPTorsionForce_getMapParameters(const OpenMM_CMAPTorsionForce* target, int index, int* size, OpenMM_DoubleArray* energy);
extern OPENMM_EXPORT void OpenMM_CMAPTorsionForce_setMapParameters(OpenMM_CMAPTorsionForce* target, int index, int size, const OpenMM_DoubleArray* energy);
extern OPENMM_EXPORT int OpenMM_CMAPTorsionForce_addTorsion(OpenMM_CMAPTorsionForce* target, int map, int a1, int a2, int a3, int a4, int b1, int b2, int b3, int b4);
extern OPENMM_EXPORT void OpenMM_CMAPTorsionForce_getTorsionParameters(const OpenMM_CMAPTorsionForce* target, int index, int* map, int* a1, int* a2, int* a3, int* a4, int* b1, int* b2, int* b3, int* b4);
extern OPENMM_EXPORT void OpenMM_CMAPTorsionForce_setTorsionParameters(OpenMM_CMAPTorsionForce* target, int index, int map, int a1, int a2, int a3, int a4, int b1, int b2, int b3, int b4);
extern OPENMM_EXPORT void OpenMM_CMAPTorsionForce_updateParametersInContext(OpenMM_CMAPTorsionForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT void OpenMM_CMAPTorsionForce_setUsesPeriodicBoundaryConditions(OpenMM_CMAPTorsionForce* target, OpenMM_Boolean periodic);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_CMAPTorsionForce_usesPeriodicBoundaryConditions(const OpenMM_CMAPTorsionForce* target);

/* Continuous3DFunction */
extern OPENMM_EXPORT OpenMM_Continuous3DFunction* OpenMM_Continuous3DFunction_create(int xsize, int ysize, int zsize, const OpenMM_DoubleArray* values, double xmin, double xmax, double ymin, double ymax, double zmin, double zmax, OpenMM_Boolean periodic);
extern OPENMM_EXPORT void OpenMM_Continuous3DFunction_destroy(OpenMM_Continuous3DFunction* target);
extern OPENMM_EXPORT void OpenMM_Continuous3DFunction_getFunctionParameters(const OpenMM_Continuous3DFunction* target, int* xsize, int* ysize, int* zsize, OpenMM_DoubleArray* values, double* xmin, double* xmax, double* ymin, double* ymax, double* zmin, double* zmax);
extern OPENMM_EXPORT void OpenMM_Continuous3DFunction_setFunctionParameters(OpenMM_Continuous3DFunction* target, int xsize, int ysize, int zsize, const OpenMM_DoubleArray* values, double xmin, double xmax, double ymin, double ymax, double zmin, double zmax);
extern OPENMM_EXPORT OpenMM_Continuous3DFunction* OpenMM_Continuous3DFunction_Copy(const OpenMM_Continuous3DFunction* target);

/* OutOfPlaneSite */
extern OPENMM_EXPORT OpenMM_OutOfPlaneSite* OpenMM_OutOfPlaneSite_create(int particle1, int particle2, int particle3, double weight12, double weight13, double weightCross);
extern OPENMM_EXPORT void OpenMM_OutOfPlaneSite_destroy(OpenMM_OutOfPlaneSite* target);
extern OPENMM_EXPORT double OpenMM_OutOfPlaneSite_getWeight12(const OpenMM_OutOfPlaneSite* target);
extern OPENMM_EXPORT double OpenMM_OutOfPlaneSite_getWeight13(const OpenMM_OutOfPlaneSite* target);
extern OPENMM_EXPORT double OpenMM_OutOfPlaneSite_getWeightCross(const OpenMM_OutOfPlaneSite* target);

/* Discrete1DFunction */
extern OPENMM_EXPORT OpenMM_Discrete1DFunction* OpenMM_Discrete1DFunction_create(const OpenMM_DoubleArray* values);
extern OPENMM_EXPORT void OpenMM_Discrete1DFunction_destroy(OpenMM_Discrete1DFunction* target);
extern OPENMM_EXPORT void OpenMM_Discrete1DFunction_getFunctionParameters(const OpenMM_Discrete1DFunction* target, OpenMM_DoubleArray* values);
extern OPENMM_EXPORT void OpenMM_Discrete1DFunction_setFunctionParameters(OpenMM_Discrete1DFunction* target, const OpenMM_DoubleArray* values);
extern OPENMM_EXPORT OpenMM_Discrete1DFunction* OpenMM_Discrete1DFunction_Copy(const OpenMM_Discrete1DFunction* target);

/* CustomTorsionForce */
extern OPENMM_EXPORT OpenMM_CustomTorsionForce* OpenMM_CustomTorsionForce_create(const char* energy);
extern OPENMM_EXPORT void OpenMM_CustomTorsionForce_destroy(OpenMM_CustomTorsionForce* target);
extern OPENMM_EXPORT int OpenMM_CustomTorsionForce_getNumTorsions(const OpenMM_CustomTorsionForce* target);
extern OPENMM_EXPORT int OpenMM_CustomTorsionForce_getNumPerTorsionParameters(const OpenMM_CustomTorsionForce* target);
extern OPENMM_EXPORT int OpenMM_CustomTorsionForce_getNumGlobalParameters(const OpenMM_CustomTorsionForce* target);
extern OPENMM_EXPORT int OpenMM_CustomTorsionForce_getNumEnergyParameterDerivatives(const OpenMM_CustomTorsionForce* target);
extern OPENMM_EXPORT const char* OpenMM_CustomTorsionForce_getEnergyFunction(const OpenMM_CustomTorsionForce* target);
extern OPENMM_EXPORT void OpenMM_CustomTorsionForce_setEnergyFunction(OpenMM_CustomTorsionForce* target, const char* energy);
extern OPENMM_EXPORT int OpenMM_CustomTorsionForce_addPerTorsionParameter(OpenMM_CustomTorsionForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomTorsionForce_getPerTorsionParameterName(const OpenMM_CustomTorsionForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomTorsionForce_setPerTorsionParameterName(OpenMM_CustomTorsionForce* target, int index, const char* name);
extern OPENMM_EXPORT int OpenMM_CustomTorsionForce_addGlobalParameter(OpenMM_CustomTorsionForce* target, const char* name, double defaultValue);
extern OPENMM_EXPORT const char* OpenMM_CustomTorsionForce_getGlobalParameterName(const OpenMM_CustomTorsionForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomTorsionForce_setGlobalParameterName(OpenMM_CustomTorsionForce* target, int index, const char* name);
extern OPENMM_EXPORT double OpenMM_CustomTorsionForce_getGlobalParameterDefaultValue(const OpenMM_CustomTorsionForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomTorsionForce_setGlobalParameterDefaultValue(OpenMM_CustomTorsionForce* target, int index, double defaultValue);
extern OPENMM_EXPORT void OpenMM_CustomTorsionForce_addEnergyParameterDerivative(OpenMM_CustomTorsionForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomTorsionForce_getEnergyParameterDerivativeName(const OpenMM_CustomTorsionForce* target, int index);
extern OPENMM_EXPORT int OpenMM_CustomTorsionForce_addTorsion(OpenMM_CustomTorsionForce* target, int particle1, int particle2, int particle3, int particle4, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomTorsionForce_getTorsionParameters(const OpenMM_CustomTorsionForce* target, int index, int* particle1, int* particle2, int* particle3, int* particle4, OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomTorsionForce_setTorsionParameters(OpenMM_CustomTorsionForce* target, int index, int particle1, int particle2, int particle3, int particle4, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomTorsionForce_updateParametersInContext(OpenMM_CustomTorsionForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT void OpenMM_CustomTorsionForce_setUsesPeriodicBoundaryConditions(OpenMM_CustomTorsionForce* target, OpenMM_Boolean periodic);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_CustomTorsionForce_usesPeriodicBoundaryConditions(const OpenMM_CustomTorsionForce* target);

/* HarmonicBondForce */
extern OPENMM_EXPORT OpenMM_HarmonicBondForce* OpenMM_HarmonicBondForce_create();
extern OPENMM_EXPORT void OpenMM_HarmonicBondForce_destroy(OpenMM_HarmonicBondForce* target);
extern OPENMM_EXPORT int OpenMM_HarmonicBondForce_getNumBonds(const OpenMM_HarmonicBondForce* target);
extern OPENMM_EXPORT int OpenMM_HarmonicBondForce_addBond(OpenMM_HarmonicBondForce* target, int particle1, int particle2, double length, double k);
extern OPENMM_EXPORT void OpenMM_HarmonicBondForce_getBondParameters(const OpenMM_HarmonicBondForce* target, int index, int* particle1, int* particle2, double* length, double* k);
extern OPENMM_EXPORT void OpenMM_HarmonicBondForce_setBondParameters(OpenMM_HarmonicBondForce* target, int index, int particle1, int particle2, double length, double k);
extern OPENMM_EXPORT void OpenMM_HarmonicBondForce_updateParametersInContext(OpenMM_HarmonicBondForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT void OpenMM_HarmonicBondForce_setUsesPeriodicBoundaryConditions(OpenMM_HarmonicBondForce* target, OpenMM_Boolean periodic);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_HarmonicBondForce_usesPeriodicBoundaryConditions(const OpenMM_HarmonicBondForce* target);

/* CustomGBForce */
typedef enum {
  OpenMM_CustomGBForce_NoCutoff = 0, OpenMM_CustomGBForce_CutoffNonPeriodic = 1, OpenMM_CustomGBForce_CutoffPeriodic = 2
} OpenMM_CustomGBForce_NonbondedMethod;
typedef enum {
  OpenMM_CustomGBForce_SingleParticle = 0, OpenMM_CustomGBForce_ParticlePair = 1, OpenMM_CustomGBForce_ParticlePairNoExclusions = 2
} OpenMM_CustomGBForce_ComputationType;

extern OPENMM_EXPORT OpenMM_CustomGBForce* OpenMM_CustomGBForce_create();
extern OPENMM_EXPORT void OpenMM_CustomGBForce_destroy(OpenMM_CustomGBForce* target);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_getNumParticles(const OpenMM_CustomGBForce* target);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_getNumExclusions(const OpenMM_CustomGBForce* target);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_getNumPerParticleParameters(const OpenMM_CustomGBForce* target);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_getNumGlobalParameters(const OpenMM_CustomGBForce* target);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_getNumEnergyParameterDerivatives(const OpenMM_CustomGBForce* target);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_getNumTabulatedFunctions(const OpenMM_CustomGBForce* target);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_getNumFunctions(const OpenMM_CustomGBForce* target);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_getNumComputedValues(const OpenMM_CustomGBForce* target);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_getNumEnergyTerms(const OpenMM_CustomGBForce* target);
extern OPENMM_EXPORT OpenMM_CustomGBForce_NonbondedMethod OpenMM_CustomGBForce_getNonbondedMethod(const OpenMM_CustomGBForce* target);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_setNonbondedMethod(OpenMM_CustomGBForce* target, OpenMM_CustomGBForce_NonbondedMethod method);
extern OPENMM_EXPORT double OpenMM_CustomGBForce_getCutoffDistance(const OpenMM_CustomGBForce* target);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_setCutoffDistance(OpenMM_CustomGBForce* target, double distance);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_addPerParticleParameter(OpenMM_CustomGBForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomGBForce_getPerParticleParameterName(const OpenMM_CustomGBForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_setPerParticleParameterName(OpenMM_CustomGBForce* target, int index, const char* name);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_addGlobalParameter(OpenMM_CustomGBForce* target, const char* name, double defaultValue);
extern OPENMM_EXPORT const char* OpenMM_CustomGBForce_getGlobalParameterName(const OpenMM_CustomGBForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_setGlobalParameterName(OpenMM_CustomGBForce* target, int index, const char* name);
extern OPENMM_EXPORT double OpenMM_CustomGBForce_getGlobalParameterDefaultValue(const OpenMM_CustomGBForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_setGlobalParameterDefaultValue(OpenMM_CustomGBForce* target, int index, double defaultValue);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_addEnergyParameterDerivative(OpenMM_CustomGBForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomGBForce_getEnergyParameterDerivativeName(const OpenMM_CustomGBForce* target, int index);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_addParticle(OpenMM_CustomGBForce* target, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_getParticleParameters(const OpenMM_CustomGBForce* target, int index, OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_setParticleParameters(OpenMM_CustomGBForce* target, int index, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_addComputedValue(OpenMM_CustomGBForce* target, const char* name, const char* expression, OpenMM_CustomGBForce_ComputationType type);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_getComputedValueParameters(const OpenMM_CustomGBForce* target, int index, char** name, char** expression, OpenMM_CustomGBForce_ComputationType* type);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_setComputedValueParameters(OpenMM_CustomGBForce* target, int index, const char* name, const char* expression, OpenMM_CustomGBForce_ComputationType type);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_addEnergyTerm(OpenMM_CustomGBForce* target, const char* expression, OpenMM_CustomGBForce_ComputationType type);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_getEnergyTermParameters(const OpenMM_CustomGBForce* target, int index, char** expression, OpenMM_CustomGBForce_ComputationType* type);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_setEnergyTermParameters(OpenMM_CustomGBForce* target, int index, const char* expression, OpenMM_CustomGBForce_ComputationType type);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_addExclusion(OpenMM_CustomGBForce* target, int particle1, int particle2);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_getExclusionParticles(const OpenMM_CustomGBForce* target, int index, int* particle1, int* particle2);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_setExclusionParticles(OpenMM_CustomGBForce* target, int index, int particle1, int particle2);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_addTabulatedFunction(OpenMM_CustomGBForce* target, const char* name, OpenMM_TabulatedFunction* function);
extern OPENMM_EXPORT OpenMM_TabulatedFunction* OpenMM_CustomGBForce_getTabulatedFunction(OpenMM_CustomGBForce* target, int index);
extern OPENMM_EXPORT const char* OpenMM_CustomGBForce_getTabulatedFunctionName(const OpenMM_CustomGBForce* target, int index);
extern OPENMM_EXPORT int OpenMM_CustomGBForce_addFunction(OpenMM_CustomGBForce* target, const char* name, const OpenMM_DoubleArray* values, double min, double max);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_getFunctionParameters(const OpenMM_CustomGBForce* target, int index, char** name, OpenMM_DoubleArray* values, double* min, double* max);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_setFunctionParameters(OpenMM_CustomGBForce* target, int index, const char* name, const OpenMM_DoubleArray* values, double min, double max);
extern OPENMM_EXPORT void OpenMM_CustomGBForce_updateParametersInContext(OpenMM_CustomGBForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_CustomGBForce_usesPeriodicBoundaryConditions(const OpenMM_CustomGBForce* target);

/* RMSDForce */
extern OPENMM_EXPORT OpenMM_RMSDForce* OpenMM_RMSDForce_create(const OpenMM_Vec3Array* referencePositions, const OpenMM_IntArray* particles);
extern OPENMM_EXPORT void OpenMM_RMSDForce_destroy(OpenMM_RMSDForce* target);
extern OPENMM_EXPORT const OpenMM_Vec3Array* OpenMM_RMSDForce_getReferencePositions(const OpenMM_RMSDForce* target);
extern OPENMM_EXPORT void OpenMM_RMSDForce_setReferencePositions(OpenMM_RMSDForce* target, const OpenMM_Vec3Array* positions);
extern OPENMM_EXPORT const OpenMM_IntArray* OpenMM_RMSDForce_getParticles(const OpenMM_RMSDForce* target);
extern OPENMM_EXPORT void OpenMM_RMSDForce_setParticles(OpenMM_RMSDForce* target, const OpenMM_IntArray* particles);
extern OPENMM_EXPORT void OpenMM_RMSDForce_updateParametersInContext(OpenMM_RMSDForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_RMSDForce_usesPeriodicBoundaryConditions(const OpenMM_RMSDForce* target);

/* CustomExternalForce */
extern OPENMM_EXPORT OpenMM_CustomExternalForce* OpenMM_CustomExternalForce_create(const char* energy);
extern OPENMM_EXPORT void OpenMM_CustomExternalForce_destroy(OpenMM_CustomExternalForce* target);
extern OPENMM_EXPORT int OpenMM_CustomExternalForce_getNumParticles(const OpenMM_CustomExternalForce* target);
extern OPENMM_EXPORT int OpenMM_CustomExternalForce_getNumPerParticleParameters(const OpenMM_CustomExternalForce* target);
extern OPENMM_EXPORT int OpenMM_CustomExternalForce_getNumGlobalParameters(const OpenMM_CustomExternalForce* target);
extern OPENMM_EXPORT const char* OpenMM_CustomExternalForce_getEnergyFunction(const OpenMM_CustomExternalForce* target);
extern OPENMM_EXPORT void OpenMM_CustomExternalForce_setEnergyFunction(OpenMM_CustomExternalForce* target, const char* energy);
extern OPENMM_EXPORT int OpenMM_CustomExternalForce_addPerParticleParameter(OpenMM_CustomExternalForce* target, const char* name);
extern OPENMM_EXPORT const char* OpenMM_CustomExternalForce_getPerParticleParameterName(const OpenMM_CustomExternalForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomExternalForce_setPerParticleParameterName(OpenMM_CustomExternalForce* target, int index, const char* name);
extern OPENMM_EXPORT int OpenMM_CustomExternalForce_addGlobalParameter(OpenMM_CustomExternalForce* target, const char* name, double defaultValue);
extern OPENMM_EXPORT const char* OpenMM_CustomExternalForce_getGlobalParameterName(const OpenMM_CustomExternalForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomExternalForce_setGlobalParameterName(OpenMM_CustomExternalForce* target, int index, const char* name);
extern OPENMM_EXPORT double OpenMM_CustomExternalForce_getGlobalParameterDefaultValue(const OpenMM_CustomExternalForce* target, int index);
extern OPENMM_EXPORT void OpenMM_CustomExternalForce_setGlobalParameterDefaultValue(OpenMM_CustomExternalForce* target, int index, double defaultValue);
extern OPENMM_EXPORT int OpenMM_CustomExternalForce_addParticle(OpenMM_CustomExternalForce* target, int particle, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomExternalForce_getParticleParameters(const OpenMM_CustomExternalForce* target, int index, int* particle, OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomExternalForce_setParticleParameters(OpenMM_CustomExternalForce* target, int index, int particle, const OpenMM_DoubleArray* parameters);
extern OPENMM_EXPORT void OpenMM_CustomExternalForce_updateParametersInContext(OpenMM_CustomExternalForce* target, OpenMM_Context* context);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_CustomExternalForce_usesPeriodicBoundaryConditions(const OpenMM_CustomExternalForce* target);

/* Continuous2DFunction */
extern OPENMM_EXPORT OpenMM_Continuous2DFunction* OpenMM_Continuous2DFunction_create(int xsize, int ysize, const OpenMM_DoubleArray* values, double xmin, double xmax, double ymin, double ymax, OpenMM_Boolean periodic);
extern OPENMM_EXPORT void OpenMM_Continuous2DFunction_destroy(OpenMM_Continuous2DFunction* target);
extern OPENMM_EXPORT void OpenMM_Continuous2DFunction_getFunctionParameters(const OpenMM_Continuous2DFunction* target, int* xsize, int* ysize, OpenMM_DoubleArray* values, double* xmin, double* xmax, double* ymin, double* ymax);
extern OPENMM_EXPORT void OpenMM_Continuous2DFunction_setFunctionParameters(OpenMM_Continuous2DFunction* target, int xsize, int ysize, const OpenMM_DoubleArray* values, double xmin, double xmax, double ymin, double ymax);
extern OPENMM_EXPORT OpenMM_Continuous2DFunction* OpenMM_Continuous2DFunction_Copy(const OpenMM_Continuous2DFunction* target);

/* CMMotionRemover */
extern OPENMM_EXPORT OpenMM_CMMotionRemover* OpenMM_CMMotionRemover_create(int frequency);
extern OPENMM_EXPORT void OpenMM_CMMotionRemover_destroy(OpenMM_CMMotionRemover* target);
extern OPENMM_EXPORT int OpenMM_CMMotionRemover_getFrequency(const OpenMM_CMMotionRemover* target);
extern OPENMM_EXPORT void OpenMM_CMMotionRemover_setFrequency(OpenMM_CMMotionRemover* target, int freq);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_CMMotionRemover_usesPeriodicBoundaryConditions(const OpenMM_CMMotionRemover* target);

/* Platform */
extern OPENMM_EXPORT void OpenMM_Platform_destroy(OpenMM_Platform* target);
extern OPENMM_EXPORT void OpenMM_Platform_registerPlatform(OpenMM_Platform* platform);
extern OPENMM_EXPORT int OpenMM_Platform_getNumPlatforms();
extern OPENMM_EXPORT OpenMM_Platform* OpenMM_Platform_getPlatform(int index);
extern OPENMM_EXPORT OpenMM_Platform* OpenMM_Platform_getPlatformByName(const char* name);
extern OPENMM_EXPORT OpenMM_Platform* OpenMM_Platform_findPlatform(const OpenMM_StringArray* kernelNames);
extern OPENMM_EXPORT void OpenMM_Platform_loadPluginLibrary(const char* file);
extern OPENMM_EXPORT const char* OpenMM_Platform_getDefaultPluginsDirectory();
extern OPENMM_EXPORT const char* OpenMM_Platform_getOpenMMVersion();
extern OPENMM_EXPORT const char* OpenMM_Platform_getName(const OpenMM_Platform* target);
extern OPENMM_EXPORT double OpenMM_Platform_getSpeed(const OpenMM_Platform* target);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_Platform_supportsDoublePrecision(const OpenMM_Platform* target);
extern OPENMM_EXPORT const OpenMM_StringArray* OpenMM_Platform_getPropertyNames(const OpenMM_Platform* target);
extern OPENMM_EXPORT const char* OpenMM_Platform_getPropertyValue(const OpenMM_Platform* target, const OpenMM_Context* context, const char* property);
extern OPENMM_EXPORT void OpenMM_Platform_setPropertyValue(const OpenMM_Platform* target, OpenMM_Context* context, const char* property, const char* value);
extern OPENMM_EXPORT const char* OpenMM_Platform_getPropertyDefaultValue(const OpenMM_Platform* target, const char* property);
extern OPENMM_EXPORT void OpenMM_Platform_setPropertyDefaultValue(OpenMM_Platform* target, const char* property, const char* value);
extern OPENMM_EXPORT OpenMM_Boolean OpenMM_Platform_supportsKernels(const OpenMM_Platform* target, const OpenMM_StringArray* kernelNames);


#if defined(__cplusplus)
}
#endif

#endif /*OPENMM_CWRAPPER_H_*/
