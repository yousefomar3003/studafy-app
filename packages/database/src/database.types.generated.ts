// Generated from the local public schema. Do not edit manually.
export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Database = {
  public: {
    Tables: {
      account_deletion_requests: {
        Row: {
          cancelled_at: string | null;
          cancelled_by: string | null;
          completed_at: string | null;
          education_record_classification: string;
          execute_after: string;
          id: string;
          impact_snapshot: Json | null;
          legal_hold: boolean;
          legal_hold_reason: string | null;
          reason_code: string | null;
          requested_at: string;
          requested_via: string;
          state: string;
          updated_at: string;
          user_id: string;
          version: number;
        };
        Insert: {
          cancelled_at?: string | null;
          cancelled_by?: string | null;
          completed_at?: string | null;
          education_record_classification?: string;
          execute_after?: string;
          id?: string;
          impact_snapshot?: Json | null;
          legal_hold?: boolean;
          legal_hold_reason?: string | null;
          reason_code?: string | null;
          requested_at?: string;
          requested_via?: string;
          state?: string;
          updated_at?: string;
          user_id: string;
          version?: number;
        };
        Update: {
          cancelled_at?: string | null;
          cancelled_by?: string | null;
          completed_at?: string | null;
          education_record_classification?: string;
          execute_after?: string;
          id?: string;
          impact_snapshot?: Json | null;
          legal_hold?: boolean;
          legal_hold_reason?: string | null;
          reason_code?: string | null;
          requested_at?: string;
          requested_via?: string;
          state?: string;
          updated_at?: string;
          user_id?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "account_deletion_requests_cancelled_by_fkey";
            columns: ["cancelled_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "account_deletion_requests_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      ai_grading_drafts: {
        Row: {
          created_at: string;
          created_by: string;
          file_object_id: string | null;
          grade_result_id: string;
          id: string;
          model_version: string;
          private_scan_path: string;
          school_id: string;
          status: string;
          strictness: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          created_at?: string;
          created_by: string;
          file_object_id?: string | null;
          grade_result_id: string;
          id?: string;
          model_version: string;
          private_scan_path: string;
          school_id: string;
          status?: string;
          strictness: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          created_at?: string;
          created_by?: string;
          file_object_id?: string | null;
          grade_result_id?: string;
          id?: string;
          model_version?: string;
          private_scan_path?: string;
          school_id?: string;
          status?: string;
          strictness?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "ai_grading_drafts_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "ai_grading_drafts_file_object_id_fkey";
            columns: ["file_object_id"];
            isOneToOne: false;
            referencedRelation: "file_objects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "ai_grading_drafts_grade_result_id_fkey";
            columns: ["grade_result_id"];
            isOneToOne: false;
            referencedRelation: "grade_results";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "db020_ai_grading_drafts_file_school_fk";
            columns: ["school_id", "file_object_id"];
            isOneToOne: false;
            referencedRelation: "file_objects";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_ai_grading_drafts_grade_school_fk";
            columns: ["school_id", "grade_result_id"];
            isOneToOne: false;
            referencedRelation: "grade_results";
            referencedColumns: ["school_id", "id"];
          },
        ];
      };
      announcements: {
        Row: {
          audience: Database["public"]["Enums"]["meeting_audience"];
          body: string;
          classroom_id: string | null;
          created_by: string;
          deleted_at: string | null;
          id: string;
          important: boolean;
          published_at: string;
          school_id: string;
          state: Database["public"]["Enums"]["resource_state"];
          title: string;
          updated_at: string;
        };
        Insert: {
          audience?: Database["public"]["Enums"]["meeting_audience"];
          body: string;
          classroom_id?: string | null;
          created_by: string;
          deleted_at?: string | null;
          id?: string;
          important?: boolean;
          published_at?: string;
          school_id: string;
          state?: Database["public"]["Enums"]["resource_state"];
          title: string;
          updated_at?: string;
        };
        Update: {
          audience?: Database["public"]["Enums"]["meeting_audience"];
          body?: string;
          classroom_id?: string | null;
          created_by?: string;
          deleted_at?: string | null;
          id?: string;
          important?: boolean;
          published_at?: string;
          school_id?: string;
          state?: Database["public"]["Enums"]["resource_state"];
          title?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "announcements_classroom_id_fkey";
            columns: ["classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "announcements_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "announcements_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "db020_announcements_classroom_school_fk";
            columns: ["school_id", "classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["school_id", "id"];
          },
        ];
      };
      assessment_answers: {
        Row: {
          answer_text: string;
          attempt_id: string;
          created_at: string;
          question_id: string;
          school_id: string;
        };
        Insert: {
          answer_text: string;
          attempt_id: string;
          created_at?: string;
          question_id: string;
          school_id: string;
        };
        Update: {
          answer_text?: string;
          attempt_id?: string;
          created_at?: string;
          question_id?: string;
          school_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "assessment_answers_school_id_attempt_id_fkey";
            columns: ["school_id", "attempt_id"];
            isOneToOne: false;
            referencedRelation: "assessment_attempts";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "assessment_answers_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "assessment_answers_school_id_question_id_fkey";
            columns: ["school_id", "question_id"];
            isOneToOne: false;
            referencedRelation: "assessment_questions";
            referencedColumns: ["school_id", "id"];
          },
        ];
      };
      assessment_attempts: {
        Row: {
          assessment_id: string;
          created_at: string;
          id: string;
          operation_id: string;
          school_id: string;
          student_id: string;
          submitted_at: string;
          version: number;
        };
        Insert: {
          assessment_id: string;
          created_at?: string;
          id?: string;
          operation_id: string;
          school_id: string;
          student_id: string;
          submitted_at?: string;
          version?: number;
        };
        Update: {
          assessment_id?: string;
          created_at?: string;
          id?: string;
          operation_id?: string;
          school_id?: string;
          student_id?: string;
          submitted_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "assessment_attempts_school_id_assessment_id_fkey";
            columns: ["school_id", "assessment_id"];
            isOneToOne: false;
            referencedRelation: "assessments";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "assessment_attempts_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "assessment_attempts_school_id_student_id_fkey";
            columns: ["school_id", "student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["school_id", "id"];
          },
        ];
      };
      assessment_questions: {
        Row: {
          assessment_id: string;
          created_at: string;
          id: string;
          maximum_score: number;
          position: number;
          preferred_answer: string | null;
          prompt: string;
          school_id: string;
          updated_at: string;
        };
        Insert: {
          assessment_id: string;
          created_at?: string;
          id?: string;
          maximum_score: number;
          position: number;
          preferred_answer?: string | null;
          prompt: string;
          school_id: string;
          updated_at?: string;
        };
        Update: {
          assessment_id?: string;
          created_at?: string;
          id?: string;
          maximum_score?: number;
          position?: number;
          preferred_answer?: string | null;
          prompt?: string;
          school_id?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "assessment_questions_assessment_id_fkey";
            columns: ["assessment_id"];
            isOneToOne: false;
            referencedRelation: "assessments";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "db020_assessment_questions_assessment_school_fk";
            columns: ["school_id", "assessment_id"];
            isOneToOne: false;
            referencedRelation: "assessments";
            referencedColumns: ["school_id", "id"];
          },
        ];
      };
      assessments: {
        Row: {
          category: string;
          category_weight: number | null;
          classroom_id: string;
          created_at: string;
          created_by: string;
          deleted_at: string | null;
          delivery: string;
          id: string;
          maximum_score: number;
          published_at: string | null;
          scheduled_at: string | null;
          school_id: string;
          state: Database["public"]["Enums"]["publication_state"];
          title: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          category: string;
          category_weight?: number | null;
          classroom_id: string;
          created_at?: string;
          created_by: string;
          deleted_at?: string | null;
          delivery?: string;
          id?: string;
          maximum_score: number;
          published_at?: string | null;
          scheduled_at?: string | null;
          school_id: string;
          state?: Database["public"]["Enums"]["publication_state"];
          title: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          category?: string;
          category_weight?: number | null;
          classroom_id?: string;
          created_at?: string;
          created_by?: string;
          deleted_at?: string | null;
          delivery?: string;
          id?: string;
          maximum_score?: number;
          published_at?: string | null;
          scheduled_at?: string | null;
          school_id?: string;
          state?: Database["public"]["Enums"]["publication_state"];
          title?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "assessments_classroom_id_fkey";
            columns: ["classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "assessments_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "db020_assessments_classroom_school_fk";
            columns: ["school_id", "classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["school_id", "id"];
          },
        ];
      };
      assignments: {
        Row: {
          classroom_id: string;
          closes_at: string | null;
          created_at: string;
          created_by: string;
          deleted_at: string | null;
          due_at: string;
          id: string;
          instructions: string | null;
          published_at: string | null;
          school_id: string;
          state: Database["public"]["Enums"]["publication_state"];
          title: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          classroom_id: string;
          closes_at?: string | null;
          created_at?: string;
          created_by: string;
          deleted_at?: string | null;
          due_at: string;
          id?: string;
          instructions?: string | null;
          published_at?: string | null;
          school_id: string;
          state?: Database["public"]["Enums"]["publication_state"];
          title: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          classroom_id?: string;
          closes_at?: string | null;
          created_at?: string;
          created_by?: string;
          deleted_at?: string | null;
          due_at?: string;
          id?: string;
          instructions?: string | null;
          published_at?: string | null;
          school_id?: string;
          state?: Database["public"]["Enums"]["publication_state"];
          title?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "assignments_classroom_id_fkey";
            columns: ["classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "assignments_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "db020_assignments_classroom_school_fk";
            columns: ["school_id", "classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["school_id", "id"];
          },
        ];
      };
      attendance_records: {
        Row: {
          id: string;
          reason: string | null;
          recorded_at: string;
          recorded_by: string;
          school_id: string;
          session_id: string;
          state: Database["public"]["Enums"]["attendance_state"];
          student_id: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          reason?: string | null;
          recorded_at?: string;
          recorded_by: string;
          school_id: string;
          session_id: string;
          state: Database["public"]["Enums"]["attendance_state"];
          student_id: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          reason?: string | null;
          recorded_at?: string;
          recorded_by?: string;
          school_id?: string;
          session_id?: string;
          state?: Database["public"]["Enums"]["attendance_state"];
          student_id?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "attendance_records_recorded_by_fkey";
            columns: ["recorded_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "attendance_records_session_id_fkey";
            columns: ["session_id"];
            isOneToOne: false;
            referencedRelation: "lesson_sessions";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "attendance_records_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "db020_attendance_records_session_school_fk";
            columns: ["school_id", "session_id"];
            isOneToOne: false;
            referencedRelation: "lesson_sessions";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_attendance_records_student_school_fk";
            columns: ["school_id", "student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["school_id", "id"];
          },
        ];
      };
      audit_events: {
        Row: {
          action: string;
          actor_id: string | null;
          after_value: Json | null;
          before_value: Json | null;
          created_at: string;
          entity_id: string | null;
          entity_type: string;
          id: number;
          request_id: string | null;
          school_id: string | null;
        };
        Insert: {
          action: string;
          actor_id?: string | null;
          after_value?: Json | null;
          before_value?: Json | null;
          created_at?: string;
          entity_id?: string | null;
          entity_type: string;
          id?: never;
          request_id?: string | null;
          school_id?: string | null;
        };
        Update: {
          action?: string;
          actor_id?: string | null;
          after_value?: Json | null;
          before_value?: Json | null;
          created_at?: string;
          entity_id?: string | null;
          entity_type?: string;
          id?: never;
          request_id?: string | null;
          school_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "audit_events_actor_id_fkey";
            columns: ["actor_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "audit_events_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      auth_devices: {
        Row: {
          app_version: string | null;
          created_at: string;
          device_hash: string;
          display_label: string | null;
          first_seen_at: string;
          id: string;
          last_seen_at: string;
          platform: string;
          revocation_reason: string | null;
          revoked_at: string | null;
          revoked_by: string | null;
          updated_at: string;
          user_id: string;
        };
        Insert: {
          app_version?: string | null;
          created_at?: string;
          device_hash: string;
          display_label?: string | null;
          first_seen_at?: string;
          id?: string;
          last_seen_at?: string;
          platform: string;
          revocation_reason?: string | null;
          revoked_at?: string | null;
          revoked_by?: string | null;
          updated_at?: string;
          user_id: string;
        };
        Update: {
          app_version?: string | null;
          created_at?: string;
          device_hash?: string;
          display_label?: string | null;
          first_seen_at?: string;
          id?: string;
          last_seen_at?: string;
          platform?: string;
          revocation_reason?: string | null;
          revoked_at?: string | null;
          revoked_by?: string | null;
          updated_at?: string;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "auth_devices_revoked_by_fkey";
            columns: ["revoked_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "auth_devices_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      auth_identity_links: {
        Row: {
          created_at: string;
          id: string;
          is_primary: boolean;
          linked_at: string;
          linked_by: string | null;
          provider: string;
          provider_subject_hash: string;
          unlinked_at: string | null;
          unlinked_by: string | null;
          updated_at: string;
          user_id: string;
        };
        Insert: {
          created_at?: string;
          id?: string;
          is_primary?: boolean;
          linked_at?: string;
          linked_by?: string | null;
          provider: string;
          provider_subject_hash: string;
          unlinked_at?: string | null;
          unlinked_by?: string | null;
          updated_at?: string;
          user_id: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          is_primary?: boolean;
          linked_at?: string;
          linked_by?: string | null;
          provider?: string;
          provider_subject_hash?: string;
          unlinked_at?: string | null;
          unlinked_by?: string | null;
          updated_at?: string;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "auth_identity_links_linked_by_fkey";
            columns: ["linked_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "auth_identity_links_unlinked_by_fkey";
            columns: ["unlinked_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "auth_identity_links_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      auth_reauth_grants: {
        Row: {
          aal: string;
          consumed_at: string | null;
          consumed_request_id: string | null;
          expires_at: string;
          grant_hash: string;
          id: string;
          issued_at: string;
          purpose: string;
          session_id: string;
          user_id: string;
        };
        Insert: {
          aal: string;
          consumed_at?: string | null;
          consumed_request_id?: string | null;
          expires_at: string;
          grant_hash: string;
          id?: string;
          issued_at?: string;
          purpose: string;
          session_id: string;
          user_id: string;
        };
        Update: {
          aal?: string;
          consumed_at?: string | null;
          consumed_request_id?: string | null;
          expires_at?: string;
          grant_hash?: string;
          id?: string;
          issued_at?: string;
          purpose?: string;
          session_id?: string;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "auth_reauth_grants_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      auth_security_events: {
        Row: {
          aal: string | null;
          account_hash: string | null;
          actor_id: string | null;
          created_at: string;
          device_hash: string | null;
          event_type: string;
          id: number;
          ip_hash: string | null;
          method: string | null;
          outcome: string;
          reason_code: string;
          request_id: string | null;
          school_id: string | null;
          user_agent_family: string | null;
        };
        Insert: {
          aal?: string | null;
          account_hash?: string | null;
          actor_id?: string | null;
          created_at?: string;
          device_hash?: string | null;
          event_type: string;
          id?: never;
          ip_hash?: string | null;
          method?: string | null;
          outcome: string;
          reason_code: string;
          request_id?: string | null;
          school_id?: string | null;
          user_agent_family?: string | null;
        };
        Update: {
          aal?: string | null;
          account_hash?: string | null;
          actor_id?: string | null;
          created_at?: string;
          device_hash?: string | null;
          event_type?: string;
          id?: never;
          ip_hash?: string | null;
          method?: string | null;
          outcome?: string;
          reason_code?: string;
          request_id?: string | null;
          school_id?: string | null;
          user_agent_family?: string | null;
        };
        Relationships: [];
      };
      auth_session_revocations: {
        Row: {
          actor_id: string | null;
          created_at: string;
          reason: string;
          revoked_before: string;
          updated_at: string;
          user_id: string;
        };
        Insert: {
          actor_id?: string | null;
          created_at?: string;
          reason: string;
          revoked_before: string;
          updated_at?: string;
          user_id: string;
        };
        Update: {
          actor_id?: string | null;
          created_at?: string;
          reason?: string;
          revoked_before?: string;
          updated_at?: string;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "auth_session_revocations_actor_id_fkey";
            columns: ["actor_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "auth_session_revocations_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: true;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      class_schedules: {
        Row: {
          classroom_id: string;
          created_at: string;
          effective_from: string;
          effective_until: string | null;
          ends_at: string;
          id: string;
          school_id: string;
          starts_at: string;
          updated_at: string;
          weekday: number;
        };
        Insert: {
          classroom_id: string;
          created_at?: string;
          effective_from: string;
          effective_until?: string | null;
          ends_at: string;
          id?: string;
          school_id: string;
          starts_at: string;
          updated_at?: string;
          weekday: number;
        };
        Update: {
          classroom_id?: string;
          created_at?: string;
          effective_from?: string;
          effective_until?: string | null;
          ends_at?: string;
          id?: string;
          school_id?: string;
          starts_at?: string;
          updated_at?: string;
          weekday?: number;
        };
        Relationships: [
          {
            foreignKeyName: "class_schedules_classroom_id_fkey";
            columns: ["classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "class_schedules_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "db020_class_schedules_classroom_school_fk";
            columns: ["school_id", "classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["school_id", "id"];
          },
        ];
      };
      classroom_staff: {
        Row: {
          classroom_id: string;
          created_at: string;
          ends_at: string | null;
          id: string;
          membership_id: string;
          role: Database["public"]["Enums"]["classroom_staff_role"];
          school_id: string;
          starts_at: string;
          status: Database["public"]["Enums"]["staff_assignment_status"];
          updated_at: string;
          user_id: string;
        };
        Insert: {
          classroom_id: string;
          created_at?: string;
          ends_at?: string | null;
          id?: string;
          membership_id: string;
          role: Database["public"]["Enums"]["classroom_staff_role"];
          school_id: string;
          starts_at?: string;
          status?: Database["public"]["Enums"]["staff_assignment_status"];
          updated_at?: string;
          user_id: string;
        };
        Update: {
          classroom_id?: string;
          created_at?: string;
          ends_at?: string | null;
          id?: string;
          membership_id?: string;
          role?: Database["public"]["Enums"]["classroom_staff_role"];
          school_id?: string;
          starts_at?: string;
          status?: Database["public"]["Enums"]["staff_assignment_status"];
          updated_at?: string;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "classroom_staff_classroom_id_fkey";
            columns: ["classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "classroom_staff_membership_id_fkey";
            columns: ["membership_id"];
            isOneToOne: false;
            referencedRelation: "memberships";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "classroom_staff_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "classroom_staff_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "db020_classroom_staff_classroom_school_fk";
            columns: ["school_id", "classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_classroom_staff_membership_school_user_fk";
            columns: ["school_id", "membership_id", "user_id"];
            isOneToOne: false;
            referencedRelation: "memberships";
            referencedColumns: ["school_id", "id", "user_id"];
          },
        ];
      };
      classrooms: {
        Row: {
          archived_at: string | null;
          created_at: string;
          grade: string | null;
          id: string;
          name: string;
          room: string | null;
          school_id: string;
          section: string | null;
          status: Database["public"]["Enums"]["classroom_status"];
          teacher_id: string;
          term_id: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          archived_at?: string | null;
          created_at?: string;
          grade?: string | null;
          id?: string;
          name: string;
          room?: string | null;
          school_id: string;
          section?: string | null;
          status: Database["public"]["Enums"]["classroom_status"];
          teacher_id: string;
          term_id: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          archived_at?: string | null;
          created_at?: string;
          grade?: string | null;
          id?: string;
          name?: string;
          room?: string | null;
          school_id?: string;
          section?: string | null;
          status?: Database["public"]["Enums"]["classroom_status"];
          teacher_id?: string;
          term_id?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "classrooms_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "classrooms_teacher_id_fkey";
            columns: ["teacher_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "classrooms_term_id_fkey";
            columns: ["term_id"];
            isOneToOne: false;
            referencedRelation: "terms";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "db020_classrooms_term_school_fk";
            columns: ["school_id", "term_id"];
            isOneToOne: false;
            referencedRelation: "terms";
            referencedColumns: ["school_id", "id"];
          },
        ];
      };
      consent_policies: {
        Row: {
          content_hash: string;
          created_at: string;
          effective_at: string;
          id: string;
          locale: string;
          policy_version: string;
          published_at: string;
          purpose: string;
          retired_at: string | null;
          title: string;
        };
        Insert: {
          content_hash: string;
          created_at?: string;
          effective_at: string;
          id?: string;
          locale: string;
          policy_version: string;
          published_at: string;
          purpose: string;
          retired_at?: string | null;
          title: string;
        };
        Update: {
          content_hash?: string;
          created_at?: string;
          effective_at?: string;
          id?: string;
          locale?: string;
          policy_version?: string;
          published_at?: string;
          purpose?: string;
          retired_at?: string | null;
          title?: string;
        };
        Relationships: [];
      };
      consent_records: {
        Row: {
          accepted_at: string;
          id: number;
          locale: string;
          policy_id: string | null;
          policy_version: string;
          purpose: string;
          updated_at: string;
          user_id: string;
          withdrawn_at: string | null;
        };
        Insert: {
          accepted_at?: string;
          id?: never;
          locale: string;
          policy_id?: string | null;
          policy_version: string;
          purpose: string;
          updated_at?: string;
          user_id: string;
          withdrawn_at?: string | null;
        };
        Update: {
          accepted_at?: string;
          id?: never;
          locale?: string;
          policy_id?: string | null;
          policy_version?: string;
          purpose?: string;
          updated_at?: string;
          user_id?: string;
          withdrawn_at?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "consent_records_policy_id_fkey";
            columns: ["policy_id"];
            isOneToOne: false;
            referencedRelation: "consent_policies";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "consent_records_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      conversation_participants: {
        Row: {
          conversation_id: string;
          joined_at: string;
          last_read_at: string | null;
          left_at: string | null;
          school_id: string;
          user_id: string;
        };
        Insert: {
          conversation_id: string;
          joined_at?: string;
          last_read_at?: string | null;
          left_at?: string | null;
          school_id: string;
          user_id: string;
        };
        Update: {
          conversation_id?: string;
          joined_at?: string;
          last_read_at?: string | null;
          left_at?: string | null;
          school_id?: string;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "conversation_participants_conversation_id_fkey";
            columns: ["conversation_id"];
            isOneToOne: false;
            referencedRelation: "conversations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "conversation_participants_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "conversation_participants_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName:
              "db020_conversation_participants_conversation_school_fk";
            columns: ["school_id", "conversation_id"];
            isOneToOne: false;
            referencedRelation: "conversations";
            referencedColumns: ["school_id", "id"];
          },
        ];
      };
      conversations: {
        Row: {
          closed_at: string | null;
          created_at: string;
          created_by: string;
          id: string;
          school_id: string;
          state: Database["public"]["Enums"]["conversation_state"];
          subject: string | null;
          updated_at: string;
        };
        Insert: {
          closed_at?: string | null;
          created_at?: string;
          created_by: string;
          id?: string;
          school_id: string;
          state?: Database["public"]["Enums"]["conversation_state"];
          subject?: string | null;
          updated_at?: string;
        };
        Update: {
          closed_at?: string | null;
          created_at?: string;
          created_by?: string;
          id?: string;
          school_id?: string;
          state?: Database["public"]["Enums"]["conversation_state"];
          subject?: string | null;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "conversations_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "conversations_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      data_export_requests: {
        Row: {
          expires_at: string | null;
          id: string;
          ready_at: string | null;
          requested_at: string;
          status: string;
          updated_at: string;
          user_id: string;
        };
        Insert: {
          expires_at?: string | null;
          id?: string;
          ready_at?: string | null;
          requested_at?: string;
          status?: string;
          updated_at?: string;
          user_id: string;
        };
        Update: {
          expires_at?: string | null;
          id?: string;
          ready_at?: string | null;
          requested_at?: string;
          status?: string;
          updated_at?: string;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "data_export_requests_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      enrollments: {
        Row: {
          active: boolean;
          classroom_id: string;
          created_at: string;
          ends_on: string | null;
          school_id: string;
          starts_on: string;
          status: Database["public"]["Enums"]["enrollment_status"];
          student_id: string;
          updated_at: string;
        };
        Insert: {
          active?: boolean;
          classroom_id: string;
          created_at?: string;
          ends_on?: string | null;
          school_id: string;
          starts_on?: string;
          status: Database["public"]["Enums"]["enrollment_status"];
          student_id: string;
          updated_at?: string;
        };
        Update: {
          active?: boolean;
          classroom_id?: string;
          created_at?: string;
          ends_on?: string | null;
          school_id?: string;
          starts_on?: string;
          status?: Database["public"]["Enums"]["enrollment_status"];
          student_id?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "db020_enrollments_classroom_school_fk";
            columns: ["school_id", "classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_enrollments_student_school_fk";
            columns: ["school_id", "student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "enrollments_classroom_id_fkey";
            columns: ["classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "enrollments_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
      entitlements: {
        Row: {
          created_at: string;
          ends_at: string | null;
          feature_key: string;
          id: string;
          school_id: string | null;
          source: Database["public"]["Enums"]["store_platform"];
          source_transaction_id: string | null;
          starts_at: string;
          status: Database["public"]["Enums"]["entitlement_status"];
          updated_at: string;
          user_id: string;
          version: number;
        };
        Insert: {
          created_at?: string;
          ends_at?: string | null;
          feature_key: string;
          id?: string;
          school_id?: string | null;
          source: Database["public"]["Enums"]["store_platform"];
          source_transaction_id?: string | null;
          starts_at: string;
          status: Database["public"]["Enums"]["entitlement_status"];
          updated_at?: string;
          user_id: string;
          version?: number;
        };
        Update: {
          created_at?: string;
          ends_at?: string | null;
          feature_key?: string;
          id?: string;
          school_id?: string | null;
          source?: Database["public"]["Enums"]["store_platform"];
          source_transaction_id?: string | null;
          starts_at?: string;
          status?: Database["public"]["Enums"]["entitlement_status"];
          updated_at?: string;
          user_id?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "entitlements_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "entitlements_source_transaction_id_fkey";
            columns: ["source_transaction_id"];
            isOneToOne: false;
            referencedRelation: "store_transactions";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "entitlements_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      file_bindings: {
        Row: {
          ai_grading_draft_id: string | null;
          created_at: string;
          file_object_id: string;
          id: string;
          message_id: string | null;
          resource_version_id: string | null;
          school_id: string;
          submission_attempt_id: string | null;
          upload_session_id: string | null;
        };
        Insert: {
          ai_grading_draft_id?: string | null;
          created_at?: string;
          file_object_id: string;
          id?: string;
          message_id?: string | null;
          resource_version_id?: string | null;
          school_id: string;
          submission_attempt_id?: string | null;
          upload_session_id?: string | null;
        };
        Update: {
          ai_grading_draft_id?: string | null;
          created_at?: string;
          file_object_id?: string;
          id?: string;
          message_id?: string | null;
          resource_version_id?: string | null;
          school_id?: string;
          submission_attempt_id?: string | null;
          upload_session_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "db020_file_bindings_ai_draft_school_fk";
            columns: ["school_id", "ai_grading_draft_id"];
            isOneToOne: false;
            referencedRelation: "ai_grading_drafts";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_file_bindings_file_school_fk";
            columns: ["school_id", "file_object_id"];
            isOneToOne: false;
            referencedRelation: "file_objects";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_file_bindings_message_school_fk";
            columns: ["school_id", "message_id"];
            isOneToOne: false;
            referencedRelation: "messages";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_file_bindings_resource_version_school_fk";
            columns: ["school_id", "resource_version_id"];
            isOneToOne: false;
            referencedRelation: "resource_versions";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_file_bindings_submission_attempt_school_fk";
            columns: ["school_id", "submission_attempt_id"];
            isOneToOne: false;
            referencedRelation: "submission_attempts";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "file_bindings_ai_grading_draft_id_fkey";
            columns: ["ai_grading_draft_id"];
            isOneToOne: false;
            referencedRelation: "ai_grading_drafts";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "file_bindings_file_object_id_fkey";
            columns: ["file_object_id"];
            isOneToOne: false;
            referencedRelation: "file_objects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "file_bindings_message_id_fkey";
            columns: ["message_id"];
            isOneToOne: false;
            referencedRelation: "messages";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "file_bindings_resource_version_id_fkey";
            columns: ["resource_version_id"];
            isOneToOne: false;
            referencedRelation: "resource_versions";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "file_bindings_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "file_bindings_submission_attempt_id_fkey";
            columns: ["submission_attempt_id"];
            isOneToOne: false;
            referencedRelation: "submission_attempts";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "file050_binding_upload_school_fk";
            columns: ["school_id", "upload_session_id"];
            isOneToOne: false;
            referencedRelation: "upload_sessions";
            referencedColumns: ["school_id", "id"];
          },
        ];
      };
      file_delivery_grants: {
        Row: {
          consumed_at: string | null;
          created_at: string;
          expires_at: string;
          file_object_id: string;
          id: string;
          nonce_hash: string;
          recipient_id: string;
          request_id: string | null;
          school_id: string;
          state: string;
        };
        Insert: {
          consumed_at?: string | null;
          created_at?: string;
          expires_at: string;
          file_object_id: string;
          id?: string;
          nonce_hash: string;
          recipient_id: string;
          request_id?: string | null;
          school_id: string;
          state?: string;
        };
        Update: {
          consumed_at?: string | null;
          created_at?: string;
          expires_at?: string;
          file_object_id?: string;
          id?: string;
          nonce_hash?: string;
          recipient_id?: string;
          request_id?: string | null;
          school_id?: string;
          state?: string;
        };
        Relationships: [
          {
            foreignKeyName: "file_delivery_grants_recipient_id_fkey";
            columns: ["recipient_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName:
              "file_delivery_grants_school_id_file_object_id_fkey";
            columns: ["school_id", "file_object_id"];
            isOneToOne: false;
            referencedRelation: "file_objects";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "file_delivery_grants_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      file_job_outbox: {
        Row: {
          attempt_count: number;
          available_at: string;
          completed_at: string | null;
          created_at: string;
          file_object_id: string | null;
          id: number;
          job_type: string;
          last_error_code: string | null;
          locked_at: string | null;
          locked_by: string | null;
          school_id: string;
          state: Database["public"]["Enums"]["outbox_state"];
          upload_session_id: string | null;
        };
        Insert: {
          attempt_count?: number;
          available_at?: string;
          completed_at?: string | null;
          created_at?: string;
          file_object_id?: string | null;
          id?: never;
          job_type: string;
          last_error_code?: string | null;
          locked_at?: string | null;
          locked_by?: string | null;
          school_id: string;
          state?: Database["public"]["Enums"]["outbox_state"];
          upload_session_id?: string | null;
        };
        Update: {
          attempt_count?: number;
          available_at?: string;
          completed_at?: string | null;
          created_at?: string;
          file_object_id?: string | null;
          id?: never;
          job_type?: string;
          last_error_code?: string | null;
          locked_at?: string | null;
          locked_by?: string | null;
          school_id?: string;
          state?: Database["public"]["Enums"]["outbox_state"];
          upload_session_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "file_job_outbox_school_id_file_object_id_fkey";
            columns: ["school_id", "file_object_id"];
            isOneToOne: false;
            referencedRelation: "file_objects";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "file_job_outbox_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "file_job_outbox_school_id_upload_session_id_fkey";
            columns: ["school_id", "upload_session_id"];
            isOneToOne: false;
            referencedRelation: "upload_sessions";
            referencedColumns: ["school_id", "id"];
          },
        ];
      };
      file_objects: {
        Row: {
          bucket: string;
          created_at: string;
          declared_media_type: string | null;
          dedup_source_file_id: string | null;
          deleted_at: string | null;
          detected_media_type: string | null;
          display_name: string | null;
          encryption_key_id: string | null;
          id: string;
          legal_hold: boolean;
          object_key: string;
          owner_id: string | null;
          owner_membership_id: string | null;
          physical_deleted_at: string | null;
          policy_version: string;
          purpose: Database["public"]["Enums"]["file_purpose"] | null;
          retention_until: string | null;
          scan_duration_ms: number | null;
          scan_error_code: string | null;
          scan_policy_version: string | null;
          scan_state: Database["public"]["Enums"]["file_scan_state"];
          scanned_at: string | null;
          school_id: string;
          sha256: string | null;
          size_bytes: number;
          stored_sha256: string | null;
          stored_size_bytes: number | null;
          transform_policy_version: string | null;
          uploader_id: string;
        };
        Insert: {
          bucket: string;
          created_at?: string;
          declared_media_type?: string | null;
          dedup_source_file_id?: string | null;
          deleted_at?: string | null;
          detected_media_type?: string | null;
          display_name?: string | null;
          encryption_key_id?: string | null;
          id?: string;
          legal_hold?: boolean;
          object_key: string;
          owner_id?: string | null;
          owner_membership_id?: string | null;
          physical_deleted_at?: string | null;
          policy_version?: string;
          purpose?: Database["public"]["Enums"]["file_purpose"] | null;
          retention_until?: string | null;
          scan_duration_ms?: number | null;
          scan_error_code?: string | null;
          scan_policy_version?: string | null;
          scan_state?: Database["public"]["Enums"]["file_scan_state"];
          scanned_at?: string | null;
          school_id: string;
          sha256?: string | null;
          size_bytes: number;
          stored_sha256?: string | null;
          stored_size_bytes?: number | null;
          transform_policy_version?: string | null;
          uploader_id: string;
        };
        Update: {
          bucket?: string;
          created_at?: string;
          declared_media_type?: string | null;
          dedup_source_file_id?: string | null;
          deleted_at?: string | null;
          detected_media_type?: string | null;
          display_name?: string | null;
          encryption_key_id?: string | null;
          id?: string;
          legal_hold?: boolean;
          object_key?: string;
          owner_id?: string | null;
          owner_membership_id?: string | null;
          physical_deleted_at?: string | null;
          policy_version?: string;
          purpose?: Database["public"]["Enums"]["file_purpose"] | null;
          retention_until?: string | null;
          scan_duration_ms?: number | null;
          scan_error_code?: string | null;
          scan_policy_version?: string | null;
          scan_state?: Database["public"]["Enums"]["file_scan_state"];
          scanned_at?: string | null;
          school_id?: string;
          sha256?: string | null;
          size_bytes?: number;
          stored_sha256?: string | null;
          stored_size_bytes?: number | null;
          transform_policy_version?: string | null;
          uploader_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "file_objects_owner_id_fkey";
            columns: ["owner_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "file_objects_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "file_objects_uploader_id_fkey";
            columns: ["uploader_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "file050_file_owner_school_fk";
            columns: ["school_id", "owner_membership_id", "owner_id"];
            isOneToOne: false;
            referencedRelation: "memberships";
            referencedColumns: ["school_id", "id", "user_id"];
          },
          {
            foreignKeyName: "file051_file_dedup_same_school_fk";
            columns: ["school_id", "dedup_source_file_id"];
            isOneToOne: false;
            referencedRelation: "file_objects";
            referencedColumns: ["school_id", "id"];
          },
        ];
      };
      file_purpose_policies: {
        Row: {
          allowed_media_types: string[];
          enabled: boolean;
          maximum_size_bytes: number;
          policy_version: string;
          purpose: Database["public"]["Enums"]["file_purpose"];
          retention_interval_days: number | null;
          updated_at: string;
        };
        Insert: {
          allowed_media_types: string[];
          enabled?: boolean;
          maximum_size_bytes: number;
          policy_version: string;
          purpose: Database["public"]["Enums"]["file_purpose"];
          retention_interval_days?: number | null;
          updated_at?: string;
        };
        Update: {
          allowed_media_types?: string[];
          enabled?: boolean;
          maximum_size_bytes?: number;
          policy_version?: string;
          purpose?: Database["public"]["Enums"]["file_purpose"];
          retention_interval_days?: number | null;
          updated_at?: string;
        };
        Relationships: [];
      };
      file_quota_policies: {
        Row: {
          school_id: string;
          school_live_objects: number;
          school_rolling_bytes: number;
          school_stored_bytes: number;
          updated_at: string;
          user_active_sessions: number;
          user_hourly_intents: number;
          user_rolling_bytes: number;
        };
        Insert: {
          school_id: string;
          school_live_objects?: number;
          school_rolling_bytes?: number;
          school_stored_bytes?: number;
          updated_at?: string;
          user_active_sessions?: number;
          user_hourly_intents?: number;
          user_rolling_bytes?: number;
        };
        Update: {
          school_id?: string;
          school_live_objects?: number;
          school_rolling_bytes?: number;
          school_stored_bytes?: number;
          updated_at?: string;
          user_active_sessions?: number;
          user_hourly_intents?: number;
          user_rolling_bytes?: number;
        };
        Relationships: [
          {
            foreignKeyName: "file_quota_policies_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: true;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      grade_result_events: {
        Row: {
          actor_id: string | null;
          created_at: string;
          event_type: string;
          grade_result_id: string;
          id: number;
          idempotency_key: string;
          next_state: Database["public"]["Enums"]["publication_state"];
          previous_state:
            | Database["public"]["Enums"]["publication_state"]
            | null;
          reason: string | null;
          school_id: string;
        };
        Insert: {
          actor_id?: string | null;
          created_at?: string;
          event_type: string;
          grade_result_id: string;
          id?: never;
          idempotency_key: string;
          next_state: Database["public"]["Enums"]["publication_state"];
          previous_state?:
            | Database["public"]["Enums"]["publication_state"]
            | null;
          reason?: string | null;
          school_id: string;
        };
        Update: {
          actor_id?: string | null;
          created_at?: string;
          event_type?: string;
          grade_result_id?: string;
          id?: never;
          idempotency_key?: string;
          next_state?: Database["public"]["Enums"]["publication_state"];
          previous_state?:
            | Database["public"]["Enums"]["publication_state"]
            | null;
          reason?: string | null;
          school_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "db020_grade_result_events_grade_school_fk";
            columns: ["school_id", "grade_result_id"];
            isOneToOne: false;
            referencedRelation: "grade_results";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "grade_result_events_actor_id_fkey";
            columns: ["actor_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "grade_result_events_grade_result_id_fkey";
            columns: ["grade_result_id"];
            isOneToOne: false;
            referencedRelation: "grade_results";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "grade_result_events_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      grade_results: {
        Row: {
          assessment_id: string;
          created_at: string;
          feedback: string | null;
          id: string;
          published_at: string | null;
          published_by: string | null;
          reviewed_at: string | null;
          reviewed_by: string | null;
          school_id: string;
          score: number | null;
          state: Database["public"]["Enums"]["publication_state"];
          student_id: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          assessment_id: string;
          created_at?: string;
          feedback?: string | null;
          id?: string;
          published_at?: string | null;
          published_by?: string | null;
          reviewed_at?: string | null;
          reviewed_by?: string | null;
          school_id: string;
          score?: number | null;
          state?: Database["public"]["Enums"]["publication_state"];
          student_id: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          assessment_id?: string;
          created_at?: string;
          feedback?: string | null;
          id?: string;
          published_at?: string | null;
          published_by?: string | null;
          reviewed_at?: string | null;
          reviewed_by?: string | null;
          school_id?: string;
          score?: number | null;
          state?: Database["public"]["Enums"]["publication_state"];
          student_id?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "db020_grade_results_assessment_school_fk";
            columns: ["school_id", "assessment_id"];
            isOneToOne: false;
            referencedRelation: "assessments";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_grade_results_student_school_fk";
            columns: ["school_id", "student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "grade_results_assessment_id_fkey";
            columns: ["assessment_id"];
            isOneToOne: false;
            referencedRelation: "assessments";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "grade_results_published_by_fkey";
            columns: ["published_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "grade_results_reviewed_by_fkey";
            columns: ["reviewed_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "grade_results_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
      guardian_links: {
        Row: {
          evidence_file_id: string | null;
          expires_at: string | null;
          guardian_id: string;
          id: string;
          relationship: string | null;
          school_id: string;
          status: Database["public"]["Enums"]["link_status"];
          student_id: string;
          updated_at: string;
          verified_at: string | null;
          verified_by: string | null;
        };
        Insert: {
          evidence_file_id?: string | null;
          expires_at?: string | null;
          guardian_id: string;
          id?: string;
          relationship?: string | null;
          school_id: string;
          status?: Database["public"]["Enums"]["link_status"];
          student_id: string;
          updated_at?: string;
          verified_at?: string | null;
          verified_by?: string | null;
        };
        Update: {
          evidence_file_id?: string | null;
          expires_at?: string | null;
          guardian_id?: string;
          id?: string;
          relationship?: string | null;
          school_id?: string;
          status?: Database["public"]["Enums"]["link_status"];
          student_id?: string;
          updated_at?: string;
          verified_at?: string | null;
          verified_by?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "db020_guardian_links_evidence_file_school_fk";
            columns: ["school_id", "evidence_file_id"];
            isOneToOne: false;
            referencedRelation: "file_objects";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_guardian_links_student_school_fk";
            columns: ["school_id", "student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "guardian_links_evidence_file_id_fkey";
            columns: ["evidence_file_id"];
            isOneToOne: false;
            referencedRelation: "file_objects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "guardian_links_guardian_id_fkey";
            columns: ["guardian_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "guardian_links_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "guardian_links_verified_by_fkey";
            columns: ["verified_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      idempotency_records: {
        Row: {
          actor_id: string;
          created_at: string;
          expires_at: string;
          generation: number;
          id: string;
          idempotency_key: string;
          lease_expires_at: string | null;
          request_hash: string;
          response_body: Json | null;
          response_status: number | null;
          school_id: string | null;
          scope: string;
          status: string;
          updated_at: string;
        };
        Insert: {
          actor_id: string;
          created_at?: string;
          expires_at: string;
          generation?: number;
          id?: string;
          idempotency_key: string;
          lease_expires_at?: string | null;
          request_hash: string;
          response_body?: Json | null;
          response_status?: number | null;
          school_id?: string | null;
          scope: string;
          status: string;
          updated_at?: string;
        };
        Update: {
          actor_id?: string;
          created_at?: string;
          expires_at?: string;
          generation?: number;
          id?: string;
          idempotency_key?: string;
          lease_expires_at?: string | null;
          request_hash?: string;
          response_body?: Json | null;
          response_status?: number | null;
          school_id?: string | null;
          scope?: string;
          status?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "idempotency_records_actor_id_fkey";
            columns: ["actor_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "idempotency_records_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      invitations: {
        Row: {
          accepted_at: string | null;
          accepted_by: string | null;
          attempt_count: number;
          classroom_id: string | null;
          created_at: string;
          email: string;
          expires_at: string;
          id: string;
          invited_by: string;
          max_attempts: number;
          revoked_at: string | null;
          revoked_by: string | null;
          role: Database["public"]["Enums"]["app_role"];
          school_id: string;
          status: Database["public"]["Enums"]["invitation_status"];
          token_hash: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          accepted_at?: string | null;
          accepted_by?: string | null;
          attempt_count?: number;
          classroom_id?: string | null;
          created_at?: string;
          email: string;
          expires_at: string;
          id?: string;
          invited_by: string;
          max_attempts?: number;
          revoked_at?: string | null;
          revoked_by?: string | null;
          role: Database["public"]["Enums"]["app_role"];
          school_id: string;
          status?: Database["public"]["Enums"]["invitation_status"];
          token_hash: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          accepted_at?: string | null;
          accepted_by?: string | null;
          attempt_count?: number;
          classroom_id?: string | null;
          created_at?: string;
          email?: string;
          expires_at?: string;
          id?: string;
          invited_by?: string;
          max_attempts?: number;
          revoked_at?: string | null;
          revoked_by?: string | null;
          role?: Database["public"]["Enums"]["app_role"];
          school_id?: string;
          status?: Database["public"]["Enums"]["invitation_status"];
          token_hash?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "invitations_accepted_by_fkey";
            columns: ["accepted_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "invitations_classroom_id_fkey";
            columns: ["classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "invitations_invited_by_fkey";
            columns: ["invited_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "invitations_revoked_by_fkey";
            columns: ["revoked_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "invitations_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      legal_holds: {
        Row: {
          account_deletion_request_id: string | null;
          applied_to: string;
          created_at: string;
          expires_at: string | null;
          granted_by: string;
          id: string;
          reason: string;
          released_at: string | null;
          released_by: string | null;
          released_reason: string | null;
          report_id: string | null;
          school_id: string;
          status: string;
          subject_user_id: string | null;
          ticket_ref: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          account_deletion_request_id?: string | null;
          applied_to?: string;
          created_at?: string;
          expires_at?: string | null;
          granted_by: string;
          id?: string;
          reason: string;
          released_at?: string | null;
          released_by?: string | null;
          released_reason?: string | null;
          report_id?: string | null;
          school_id: string;
          status?: string;
          subject_user_id?: string | null;
          ticket_ref: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          account_deletion_request_id?: string | null;
          applied_to?: string;
          created_at?: string;
          expires_at?: string | null;
          granted_by?: string;
          id?: string;
          reason?: string;
          released_at?: string | null;
          released_by?: string | null;
          released_reason?: string | null;
          report_id?: string | null;
          school_id?: string;
          status?: string;
          subject_user_id?: string | null;
          ticket_ref?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "legal_holds_account_deletion_request_id_fkey";
            columns: ["account_deletion_request_id"];
            isOneToOne: false;
            referencedRelation: "account_deletion_requests";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "legal_holds_granted_by_fkey";
            columns: ["granted_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "legal_holds_released_by_fkey";
            columns: ["released_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "legal_holds_report_id_fkey";
            columns: ["report_id"];
            isOneToOne: false;
            referencedRelation: "reports";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "legal_holds_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "legal_holds_subject_user_id_fkey";
            columns: ["subject_user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      lesson_materials: {
        Row: {
          body: string | null;
          created_at: string;
          created_by: string;
          deleted_at: string | null;
          id: string;
          media_type: string | null;
          school_id: string;
          session_id: string;
          storage_path: string | null;
          title: string;
          updated_at: string;
        };
        Insert: {
          body?: string | null;
          created_at?: string;
          created_by: string;
          deleted_at?: string | null;
          id?: string;
          media_type?: string | null;
          school_id: string;
          session_id: string;
          storage_path?: string | null;
          title: string;
          updated_at?: string;
        };
        Update: {
          body?: string | null;
          created_at?: string;
          created_by?: string;
          deleted_at?: string | null;
          id?: string;
          media_type?: string | null;
          school_id?: string;
          session_id?: string;
          storage_path?: string | null;
          title?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "db020_lesson_materials_session_school_fk";
            columns: ["school_id", "session_id"];
            isOneToOne: false;
            referencedRelation: "lesson_sessions";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "lesson_materials_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "lesson_materials_session_id_fkey";
            columns: ["session_id"];
            isOneToOne: false;
            referencedRelation: "lesson_sessions";
            referencedColumns: ["id"];
          },
        ];
      };
      lesson_sessions: {
        Row: {
          classroom_id: string;
          created_at: string;
          ends_at: string;
          filed_at: string | null;
          id: string;
          school_id: string;
          starts_at: string;
          status: Database["public"]["Enums"]["lesson_session_status"];
          title: string | null;
          updated_at: string;
          version: number;
        };
        Insert: {
          classroom_id: string;
          created_at?: string;
          ends_at: string;
          filed_at?: string | null;
          id?: string;
          school_id: string;
          starts_at: string;
          status?: Database["public"]["Enums"]["lesson_session_status"];
          title?: string | null;
          updated_at?: string;
          version?: number;
        };
        Update: {
          classroom_id?: string;
          created_at?: string;
          ends_at?: string;
          filed_at?: string | null;
          id?: string;
          school_id?: string;
          starts_at?: string;
          status?: Database["public"]["Enums"]["lesson_session_status"];
          title?: string | null;
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "db020_lesson_sessions_classroom_school_fk";
            columns: ["school_id", "classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "lesson_sessions_classroom_id_fkey";
            columns: ["classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["id"];
          },
        ];
      };
      meeting_deliveries: {
        Row: {
          attempt_count: number;
          created_at: string;
          delivered_at: string | null;
          error: string | null;
          error_code: string | null;
          meeting_id: string;
          next_attempt_at: string | null;
          recipient_id: string;
          school_id: string;
          state: string;
          updated_at: string;
        };
        Insert: {
          attempt_count?: number;
          created_at?: string;
          delivered_at?: string | null;
          error?: string | null;
          error_code?: string | null;
          meeting_id: string;
          next_attempt_at?: string | null;
          recipient_id: string;
          school_id: string;
          state: string;
          updated_at?: string;
        };
        Update: {
          attempt_count?: number;
          created_at?: string;
          delivered_at?: string | null;
          error?: string | null;
          error_code?: string | null;
          meeting_id?: string;
          next_attempt_at?: string | null;
          recipient_id?: string;
          school_id?: string;
          state?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "db020_meeting_deliveries_meeting_school_fk";
            columns: ["school_id", "meeting_id"];
            isOneToOne: false;
            referencedRelation: "meetings";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "meeting_deliveries_meeting_id_fkey";
            columns: ["meeting_id"];
            isOneToOne: false;
            referencedRelation: "meetings";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "meeting_deliveries_recipient_id_fkey";
            columns: ["recipient_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      meetings: {
        Row: {
          audience: Database["public"]["Enums"]["meeting_audience"];
          calendar_event_id: string | null;
          classroom_id: string;
          created_at: string;
          created_by: string;
          ends_at: string;
          id: string;
          idempotency_key: string | null;
          meet_url: string | null;
          school_id: string;
          starts_at: string;
          state: string;
          title: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          audience: Database["public"]["Enums"]["meeting_audience"];
          calendar_event_id?: string | null;
          classroom_id: string;
          created_at?: string;
          created_by: string;
          ends_at: string;
          id?: string;
          idempotency_key?: string | null;
          meet_url?: string | null;
          school_id: string;
          starts_at: string;
          state?: string;
          title: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          audience?: Database["public"]["Enums"]["meeting_audience"];
          calendar_event_id?: string | null;
          classroom_id?: string;
          created_at?: string;
          created_by?: string;
          ends_at?: string;
          id?: string;
          idempotency_key?: string | null;
          meet_url?: string | null;
          school_id?: string;
          starts_at?: string;
          state?: string;
          title?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "db020_meetings_classroom_school_fk";
            columns: ["school_id", "classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "meetings_classroom_id_fkey";
            columns: ["classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "meetings_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      membership_events: {
        Row: {
          actor_id: string | null;
          created_at: string;
          event_type: string;
          id: number;
          idempotency_key: string;
          membership_id: string;
          reason: string | null;
          school_id: string;
        };
        Insert: {
          actor_id?: string | null;
          created_at?: string;
          event_type: string;
          id?: never;
          idempotency_key: string;
          membership_id: string;
          reason?: string | null;
          school_id: string;
        };
        Update: {
          actor_id?: string | null;
          created_at?: string;
          event_type?: string;
          id?: never;
          idempotency_key?: string;
          membership_id?: string;
          reason?: string | null;
          school_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "db020_membership_events_membership_school_fk";
            columns: ["school_id", "membership_id"];
            isOneToOne: false;
            referencedRelation: "memberships";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "membership_events_actor_id_fkey";
            columns: ["actor_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "membership_events_membership_id_fkey";
            columns: ["membership_id"];
            isOneToOne: false;
            referencedRelation: "memberships";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "membership_events_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      memberships: {
        Row: {
          active: boolean;
          created_at: string;
          id: string;
          role: Database["public"]["Enums"]["app_role"];
          school_id: string;
          status: Database["public"]["Enums"]["membership_status"];
          updated_at: string;
          user_id: string;
          valid_from: string;
          valid_until: string | null;
          version: number;
        };
        Insert: {
          active?: boolean;
          created_at?: string;
          id?: string;
          role: Database["public"]["Enums"]["app_role"];
          school_id: string;
          status: Database["public"]["Enums"]["membership_status"];
          updated_at?: string;
          user_id: string;
          valid_from?: string;
          valid_until?: string | null;
          version?: number;
        };
        Update: {
          active?: boolean;
          created_at?: string;
          id?: string;
          role?: Database["public"]["Enums"]["app_role"];
          school_id?: string;
          status?: Database["public"]["Enums"]["membership_status"];
          updated_at?: string;
          user_id?: string;
          valid_from?: string;
          valid_until?: string | null;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "memberships_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "memberships_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      messages: {
        Row: {
          body: string;
          client_message_id: string;
          conversation_id: string;
          created_at: string;
          deleted_at: string | null;
          edited_at: string | null;
          id: string;
          school_id: string;
          sender_id: string;
        };
        Insert: {
          body: string;
          client_message_id: string;
          conversation_id: string;
          created_at?: string;
          deleted_at?: string | null;
          edited_at?: string | null;
          id?: string;
          school_id: string;
          sender_id: string;
        };
        Update: {
          body?: string;
          client_message_id?: string;
          conversation_id?: string;
          created_at?: string;
          deleted_at?: string | null;
          edited_at?: string | null;
          id?: string;
          school_id?: string;
          sender_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "db020_messages_conversation_school_fk";
            columns: ["school_id", "conversation_id"];
            isOneToOne: false;
            referencedRelation: "conversations";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "messages_conversation_id_fkey";
            columns: ["conversation_id"];
            isOneToOne: false;
            referencedRelation: "conversations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "messages_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "messages_sender_id_fkey";
            columns: ["sender_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      moderation_access_grants: {
        Row: {
          approved_by: string | null;
          created_at: string;
          ended_at: string | null;
          expires_at: string;
          id: string;
          mfa_verified_at: string;
          reason: string;
          requested_by: string;
          requires_second_approver: boolean;
          resource_scope: Json;
          revoked_by: string | null;
          revoked_reason: string | null;
          school_id: string;
          started_at: string | null;
          status: Database["public"]["Enums"]["moderation_access_status"];
          ticket_ref: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          approved_by?: string | null;
          created_at?: string;
          ended_at?: string | null;
          expires_at: string;
          id?: string;
          mfa_verified_at: string;
          reason: string;
          requested_by: string;
          requires_second_approver?: boolean;
          resource_scope?: Json;
          revoked_by?: string | null;
          revoked_reason?: string | null;
          school_id: string;
          started_at?: string | null;
          status?: Database["public"]["Enums"]["moderation_access_status"];
          ticket_ref: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          approved_by?: string | null;
          created_at?: string;
          ended_at?: string | null;
          expires_at?: string;
          id?: string;
          mfa_verified_at?: string;
          reason?: string;
          requested_by?: string;
          requires_second_approver?: boolean;
          resource_scope?: Json;
          revoked_by?: string | null;
          revoked_reason?: string | null;
          school_id?: string;
          started_at?: string | null;
          status?: Database["public"]["Enums"]["moderation_access_status"];
          ticket_ref?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "moderation_access_grants_approved_by_fkey";
            columns: ["approved_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "moderation_access_grants_requested_by_fkey";
            columns: ["requested_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "moderation_access_grants_revoked_by_fkey";
            columns: ["revoked_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "moderation_access_grants_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      notification_deliveries: {
        Row: {
          attempt: number;
          attempted_at: string;
          channel: string;
          delivered_at: string | null;
          error_code: string | null;
          id: number;
          notification_id: string | null;
          outbox_id: number;
          provider_message_id: string | null;
          read_at: string | null;
          recipient_id: string;
          school_id: string;
          state: Database["public"]["Enums"]["delivery_state"];
        };
        Insert: {
          attempt: number;
          attempted_at?: string;
          channel: string;
          delivered_at?: string | null;
          error_code?: string | null;
          id?: never;
          notification_id?: string | null;
          outbox_id: number;
          provider_message_id?: string | null;
          read_at?: string | null;
          recipient_id: string;
          school_id: string;
          state?: Database["public"]["Enums"]["delivery_state"];
        };
        Update: {
          attempt?: number;
          attempted_at?: string;
          channel?: string;
          delivered_at?: string | null;
          error_code?: string | null;
          id?: never;
          notification_id?: string | null;
          outbox_id?: number;
          provider_message_id?: string | null;
          read_at?: string | null;
          recipient_id?: string;
          school_id?: string;
          state?: Database["public"]["Enums"]["delivery_state"];
        };
        Relationships: [
          {
            foreignKeyName:
              "db020_notification_deliveries_notification_school_fk";
            columns: ["school_id", "notification_id"];
            isOneToOne: false;
            referencedRelation: "notifications";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_notification_deliveries_outbox_school_fk";
            columns: ["school_id", "outbox_id"];
            isOneToOne: false;
            referencedRelation: "notification_outbox";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "notification_deliveries_notification_id_fkey";
            columns: ["notification_id"];
            isOneToOne: false;
            referencedRelation: "notifications";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "notification_deliveries_outbox_id_fkey";
            columns: ["outbox_id"];
            isOneToOne: false;
            referencedRelation: "notification_outbox";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "notification_deliveries_recipient_id_fkey";
            columns: ["recipient_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "notification_deliveries_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      notification_outbox: {
        Row: {
          attempt_count: number;
          audience: Json | null;
          bullmq_job_id: string | null;
          channel: string;
          created_at: string;
          dispatched_at: string | null;
          id: number;
          idempotency_key: string;
          last_error_code: string | null;
          lease_token: string | null;
          lease_until: string | null;
          next_attempt_at: string;
          payload: Json;
          recipient_id: string | null;
          school_id: string;
          source_event_id: string;
          state: Database["public"]["Enums"]["outbox_state"];
          template_key: string;
          updated_at: string;
        };
        Insert: {
          attempt_count?: number;
          audience?: Json | null;
          bullmq_job_id?: string | null;
          channel: string;
          created_at?: string;
          dispatched_at?: string | null;
          id?: never;
          idempotency_key: string;
          last_error_code?: string | null;
          lease_token?: string | null;
          lease_until?: string | null;
          next_attempt_at?: string;
          payload?: Json;
          recipient_id?: string | null;
          school_id: string;
          source_event_id: string;
          state?: Database["public"]["Enums"]["outbox_state"];
          template_key: string;
          updated_at?: string;
        };
        Update: {
          attempt_count?: number;
          audience?: Json | null;
          bullmq_job_id?: string | null;
          channel?: string;
          created_at?: string;
          dispatched_at?: string | null;
          id?: never;
          idempotency_key?: string;
          last_error_code?: string | null;
          lease_token?: string | null;
          lease_until?: string | null;
          next_attempt_at?: string;
          payload?: Json;
          recipient_id?: string | null;
          school_id?: string;
          source_event_id?: string;
          state?: Database["public"]["Enums"]["outbox_state"];
          template_key?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "notification_outbox_recipient_id_fkey";
            columns: ["recipient_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "notification_outbox_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      notification_preferences: {
        Row: {
          category: string;
          channel: string;
          enabled: boolean;
          id: string;
          school_id: string | null;
          updated_at: string;
          user_id: string;
        };
        Insert: {
          category: string;
          channel: string;
          enabled?: boolean;
          id?: string;
          school_id?: string | null;
          updated_at?: string;
          user_id: string;
        };
        Update: {
          category?: string;
          channel?: string;
          enabled?: boolean;
          id?: string;
          school_id?: string | null;
          updated_at?: string;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "notification_preferences_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "notification_preferences_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      notifications: {
        Row: {
          body: string;
          created_at: string;
          dedupe_key: string | null;
          entity_id: string | null;
          id: string;
          kind: string;
          read_at: string | null;
          route: string | null;
          school_id: string;
          source_event_id: string | null;
          title: string;
          updated_at: string;
          user_id: string;
        };
        Insert: {
          body: string;
          created_at?: string;
          dedupe_key?: string | null;
          entity_id?: string | null;
          id?: string;
          kind: string;
          read_at?: string | null;
          route?: string | null;
          school_id: string;
          source_event_id?: string | null;
          title: string;
          updated_at?: string;
          user_id: string;
        };
        Update: {
          body?: string;
          created_at?: string;
          dedupe_key?: string | null;
          entity_id?: string | null;
          id?: string;
          kind?: string;
          read_at?: string | null;
          route?: string | null;
          school_id?: string;
          source_event_id?: string | null;
          title?: string;
          updated_at?: string;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "notifications_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "notifications_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      platform_operators: {
        Row: {
          created_at: string;
          granted_by: string | null;
          note: string | null;
          user_id: string;
        };
        Insert: {
          created_at?: string;
          granted_by?: string | null;
          note?: string | null;
          user_id: string;
        };
        Update: {
          created_at?: string;
          granted_by?: string | null;
          note?: string | null;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "platform_operators_granted_by_fkey";
            columns: ["granted_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "platform_operators_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: true;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      practice_sessions: {
        Row: {
          classroom_id: string;
          completed_at: string | null;
          correct_count: number | null;
          created_at: string;
          id: string;
          item_count: number;
          kind: string;
          school_id: string;
          student_id: string;
          topic: string;
          updated_at: string;
        };
        Insert: {
          classroom_id: string;
          completed_at?: string | null;
          correct_count?: number | null;
          created_at?: string;
          id?: string;
          item_count: number;
          kind: string;
          school_id: string;
          student_id: string;
          topic: string;
          updated_at?: string;
        };
        Update: {
          classroom_id?: string;
          completed_at?: string | null;
          correct_count?: number | null;
          created_at?: string;
          id?: string;
          item_count?: number;
          kind?: string;
          school_id?: string;
          student_id?: string;
          topic?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "db020_practice_sessions_classroom_school_fk";
            columns: ["school_id", "classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_practice_sessions_student_school_fk";
            columns: ["school_id", "student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "practice_sessions_classroom_id_fkey";
            columns: ["classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "practice_sessions_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
      profiles: {
        Row: {
          created_at: string;
          deleted_at: string | null;
          display_name: string;
          id: string;
          locale: string;
          status: Database["public"]["Enums"]["profile_status"];
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          deleted_at?: string | null;
          display_name: string;
          id: string;
          locale?: string;
          status?: Database["public"]["Enums"]["profile_status"];
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          deleted_at?: string | null;
          display_name?: string;
          id?: string;
          locale?: string;
          status?: Database["public"]["Enums"]["profile_status"];
          updated_at?: string;
        };
        Relationships: [];
      };
      question_suggestions: {
        Row: {
          confidence: number;
          created_at: string;
          draft_id: string;
          id: string;
          override_reason: string | null;
          proposed_score: number;
          question_id: string;
          rationale: string;
          school_id: string;
          teacher_score: number | null;
        };
        Insert: {
          confidence: number;
          created_at?: string;
          draft_id: string;
          id?: string;
          override_reason?: string | null;
          proposed_score: number;
          question_id: string;
          rationale: string;
          school_id: string;
          teacher_score?: number | null;
        };
        Update: {
          confidence?: number;
          created_at?: string;
          draft_id?: string;
          id?: string;
          override_reason?: string | null;
          proposed_score?: number;
          question_id?: string;
          rationale?: string;
          school_id?: string;
          teacher_score?: number | null;
        };
        Relationships: [
          {
            foreignKeyName: "db020_question_suggestions_draft_school_fk";
            columns: ["school_id", "draft_id"];
            isOneToOne: false;
            referencedRelation: "ai_grading_drafts";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_question_suggestions_question_school_fk";
            columns: ["school_id", "question_id"];
            isOneToOne: false;
            referencedRelation: "assessment_questions";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "question_suggestions_draft_id_fkey";
            columns: ["draft_id"];
            isOneToOne: false;
            referencedRelation: "ai_grading_drafts";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "question_suggestions_question_id_fkey";
            columns: ["question_id"];
            isOneToOne: false;
            referencedRelation: "assessment_questions";
            referencedColumns: ["id"];
          },
        ];
      };
      report_attempts: {
        Row: {
          count_this_window: number;
          digest: string;
          id: string;
          reporter_id: string;
          school_id: string;
          window_expires_at: string;
          window_started_at: string;
        };
        Insert: {
          count_this_window?: number;
          digest: string;
          id?: string;
          reporter_id: string;
          school_id: string;
          window_expires_at: string;
          window_started_at?: string;
        };
        Update: {
          count_this_window?: number;
          digest?: string;
          id?: string;
          reporter_id?: string;
          school_id?: string;
          window_expires_at?: string;
          window_started_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "report_attempts_reporter_id_fkey";
            columns: ["reporter_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "report_attempts_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      report_events: {
        Row: {
          actor_id: string;
          created_at: string;
          detail: Json;
          event: Database["public"]["Enums"]["report_event_kind"];
          id: number;
          report_id: string;
          school_id: string;
        };
        Insert: {
          actor_id: string;
          created_at?: string;
          detail?: Json;
          event: Database["public"]["Enums"]["report_event_kind"];
          id?: never;
          report_id: string;
          school_id: string;
        };
        Update: {
          actor_id?: string;
          created_at?: string;
          detail?: Json;
          event?: Database["public"]["Enums"]["report_event_kind"];
          id?: never;
          report_id?: string;
          school_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "report_events_actor_id_fkey";
            columns: ["actor_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "report_events_report_id_fkey";
            columns: ["report_id"];
            isOneToOne: false;
            referencedRelation: "reports";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "report_events_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      report_evidence: {
        Row: {
          added_by: string;
          attachment_file_id: string | null;
          content_hash: string | null;
          created_at: string;
          id: string;
          kind: string;
          message_id: string | null;
          note: string | null;
          report_id: string;
          school_id: string;
        };
        Insert: {
          added_by: string;
          attachment_file_id?: string | null;
          content_hash?: string | null;
          created_at?: string;
          id?: string;
          kind: string;
          message_id?: string | null;
          note?: string | null;
          report_id: string;
          school_id: string;
        };
        Update: {
          added_by?: string;
          attachment_file_id?: string | null;
          content_hash?: string | null;
          created_at?: string;
          id?: string;
          kind?: string;
          message_id?: string | null;
          note?: string | null;
          report_id?: string;
          school_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "report_evidence_added_by_fkey";
            columns: ["added_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "report_evidence_attachment_file_id_fkey";
            columns: ["attachment_file_id"];
            isOneToOne: false;
            referencedRelation: "file_objects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "report_evidence_message_id_fkey";
            columns: ["message_id"];
            isOneToOne: false;
            referencedRelation: "messages";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "report_evidence_report_id_fkey";
            columns: ["report_id"];
            isOneToOne: false;
            referencedRelation: "reports";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "report_evidence_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      reports: {
        Row: {
          assigned_to: string | null;
          aup_version: string | null;
          classifier_confidence: number | null;
          contact_consent: boolean;
          conversation_id: string | null;
          created_at: string;
          details: string;
          enqueue_seq: number;
          evidence_snapshot: Json;
          id: string;
          kind: Database["public"]["Enums"]["report_kind"];
          message_id: string | null;
          priority: string;
          reported_by: string;
          resolution: Database["public"]["Enums"]["report_resolution"] | null;
          resolution_note: string | null;
          resolved_at: string | null;
          school_id: string;
          status: Database["public"]["Enums"]["report_status"];
          subject_user_id: string | null;
          updated_at: string;
          version: number;
        };
        Insert: {
          assigned_to?: string | null;
          aup_version?: string | null;
          classifier_confidence?: number | null;
          contact_consent?: boolean;
          conversation_id?: string | null;
          created_at?: string;
          details: string;
          enqueue_seq?: never;
          evidence_snapshot?: Json;
          id?: string;
          kind: Database["public"]["Enums"]["report_kind"];
          message_id?: string | null;
          priority?: string;
          reported_by: string;
          resolution?: Database["public"]["Enums"]["report_resolution"] | null;
          resolution_note?: string | null;
          resolved_at?: string | null;
          school_id: string;
          status?: Database["public"]["Enums"]["report_status"];
          subject_user_id?: string | null;
          updated_at?: string;
          version?: number;
        };
        Update: {
          assigned_to?: string | null;
          aup_version?: string | null;
          classifier_confidence?: number | null;
          contact_consent?: boolean;
          conversation_id?: string | null;
          created_at?: string;
          details?: string;
          enqueue_seq?: never;
          evidence_snapshot?: Json;
          id?: string;
          kind?: Database["public"]["Enums"]["report_kind"];
          message_id?: string | null;
          priority?: string;
          reported_by?: string;
          resolution?: Database["public"]["Enums"]["report_resolution"] | null;
          resolution_note?: string | null;
          resolved_at?: string | null;
          school_id?: string;
          status?: Database["public"]["Enums"]["report_status"];
          subject_user_id?: string | null;
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "reports_assigned_to_fkey";
            columns: ["assigned_to"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "reports_conversation_id_fkey";
            columns: ["conversation_id"];
            isOneToOne: false;
            referencedRelation: "conversations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "reports_message_id_fkey";
            columns: ["message_id"];
            isOneToOne: false;
            referencedRelation: "messages";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "reports_reported_by_fkey";
            columns: ["reported_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "reports_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "reports_subject_user_id_fkey";
            columns: ["subject_user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      resource_publications: {
        Row: {
          audience: Database["public"]["Enums"]["meeting_audience"];
          classroom_id: string | null;
          created_at: string;
          created_by: string;
          id: string;
          published_at: string | null;
          resource_version_id: string;
          school_id: string;
          state: Database["public"]["Enums"]["resource_state"];
          updated_at: string;
          version: number;
          withdrawn_at: string | null;
        };
        Insert: {
          audience?: Database["public"]["Enums"]["meeting_audience"];
          classroom_id?: string | null;
          created_at?: string;
          created_by: string;
          id?: string;
          published_at?: string | null;
          resource_version_id: string;
          school_id: string;
          state?: Database["public"]["Enums"]["resource_state"];
          updated_at?: string;
          version?: number;
          withdrawn_at?: string | null;
        };
        Update: {
          audience?: Database["public"]["Enums"]["meeting_audience"];
          classroom_id?: string | null;
          created_at?: string;
          created_by?: string;
          id?: string;
          published_at?: string | null;
          resource_version_id?: string;
          school_id?: string;
          state?: Database["public"]["Enums"]["resource_state"];
          updated_at?: string;
          version?: number;
          withdrawn_at?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "db020_resource_publications_classroom_school_fk";
            columns: ["school_id", "classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_resource_publications_version_school_fk";
            columns: ["school_id", "resource_version_id"];
            isOneToOne: false;
            referencedRelation: "resource_versions";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "resource_publications_classroom_id_fkey";
            columns: ["classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "resource_publications_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "resource_publications_resource_version_id_fkey";
            columns: ["resource_version_id"];
            isOneToOne: false;
            referencedRelation: "resource_versions";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "resource_publications_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      resource_versions: {
        Row: {
          body: string | null;
          content_hash: string | null;
          created_at: string;
          created_by: string;
          file_object_id: string | null;
          id: string;
          resource_id: string;
          school_id: string;
          version: number;
        };
        Insert: {
          body?: string | null;
          content_hash?: string | null;
          created_at?: string;
          created_by: string;
          file_object_id?: string | null;
          id?: string;
          resource_id: string;
          school_id: string;
          version: number;
        };
        Update: {
          body?: string | null;
          content_hash?: string | null;
          created_at?: string;
          created_by?: string;
          file_object_id?: string | null;
          id?: string;
          resource_id?: string;
          school_id?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "db020_resource_versions_file_school_fk";
            columns: ["school_id", "file_object_id"];
            isOneToOne: false;
            referencedRelation: "file_objects";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_resource_versions_resource_school_fk";
            columns: ["school_id", "resource_id"];
            isOneToOne: false;
            referencedRelation: "resources";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "resource_versions_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "resource_versions_file_object_id_fkey";
            columns: ["file_object_id"];
            isOneToOne: false;
            referencedRelation: "file_objects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "resource_versions_resource_id_fkey";
            columns: ["resource_id"];
            isOneToOne: false;
            referencedRelation: "resources";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "resource_versions_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      resources: {
        Row: {
          created_at: string;
          created_by: string;
          current_version: number;
          deleted_at: string | null;
          id: string;
          resource_type: string;
          school_id: string;
          state: Database["public"]["Enums"]["resource_state"];
          title: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          created_at?: string;
          created_by: string;
          current_version?: number;
          deleted_at?: string | null;
          id?: string;
          resource_type: string;
          school_id: string;
          state?: Database["public"]["Enums"]["resource_state"];
          title: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          created_at?: string;
          created_by?: string;
          current_version?: number;
          deleted_at?: string | null;
          id?: string;
          resource_type?: string;
          school_id?: string;
          state?: Database["public"]["Enums"]["resource_state"];
          title?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "resources_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "resources_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      safety_content_rules: {
        Row: {
          action: string;
          active: boolean;
          category: string;
          created_at: string;
          created_by: string | null;
          id: string;
          name: string;
          pattern: string;
          pattern_type: string;
          school_id: string;
          severity: string;
          system_rule: boolean;
          updated_at: string;
          version: number;
        };
        Insert: {
          action?: string;
          active?: boolean;
          category: string;
          created_at?: string;
          created_by?: string | null;
          id?: string;
          name: string;
          pattern: string;
          pattern_type?: string;
          school_id: string;
          severity?: string;
          system_rule?: boolean;
          updated_at?: string;
          version?: number;
        };
        Update: {
          action?: string;
          active?: boolean;
          category?: string;
          created_at?: string;
          created_by?: string | null;
          id?: string;
          name?: string;
          pattern?: string;
          pattern_type?: string;
          school_id?: string;
          severity?: string;
          system_rule?: boolean;
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "safety_content_rules_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "safety_content_rules_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      school_content_controls: {
        Row: {
          classifier_assist_enabled: boolean;
          content_filter_level: string;
          created_at: string;
          id: string;
          messaging_enabled: boolean;
          school_id: string;
          sla_hours: Json;
          support_contact: string | null;
          updated_at: string;
          updated_by: string | null;
          version: number;
        };
        Insert: {
          classifier_assist_enabled?: boolean;
          content_filter_level?: string;
          created_at?: string;
          id?: string;
          messaging_enabled?: boolean;
          school_id: string;
          sla_hours?: Json;
          support_contact?: string | null;
          updated_at?: string;
          updated_by?: string | null;
          version?: number;
        };
        Update: {
          classifier_assist_enabled?: boolean;
          content_filter_level?: string;
          created_at?: string;
          id?: string;
          messaging_enabled?: boolean;
          school_id?: string;
          sla_hours?: Json;
          support_contact?: string | null;
          updated_at?: string;
          updated_by?: string | null;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "school_content_controls_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: true;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "school_content_controls_updated_by_fkey";
            columns: ["updated_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      schools: {
        Row: {
          created_at: string;
          deleted_at: string | null;
          id: string;
          locale: string;
          name: string;
          retention_policy_version: string | null;
          status: Database["public"]["Enums"]["school_status"];
          timezone: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          created_at?: string;
          deleted_at?: string | null;
          id?: string;
          locale?: string;
          name: string;
          retention_policy_version?: string | null;
          status?: Database["public"]["Enums"]["school_status"];
          timezone?: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          created_at?: string;
          deleted_at?: string | null;
          id?: string;
          locale?: string;
          name?: string;
          retention_policy_version?: string | null;
          status?: Database["public"]["Enums"]["school_status"];
          timezone?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [];
      };
      store_events: {
        Row: {
          attempt_count: number;
          environment: string;
          external_event_id: string | null;
          id: number;
          last_error_code: string | null;
          next_attempt_at: string;
          payload_hash: string;
          platform: Database["public"]["Enums"]["store_platform"];
          processed_at: string | null;
          received_at: string;
          state: Database["public"]["Enums"]["outbox_state"];
        };
        Insert: {
          attempt_count?: number;
          environment: string;
          external_event_id?: string | null;
          id?: never;
          last_error_code?: string | null;
          next_attempt_at?: string;
          payload_hash: string;
          platform: Database["public"]["Enums"]["store_platform"];
          processed_at?: string | null;
          received_at?: string;
          state?: Database["public"]["Enums"]["outbox_state"];
        };
        Update: {
          attempt_count?: number;
          environment?: string;
          external_event_id?: string | null;
          id?: never;
          last_error_code?: string | null;
          next_attempt_at?: string;
          payload_hash?: string;
          platform?: Database["public"]["Enums"]["store_platform"];
          processed_at?: string | null;
          received_at?: string;
          state?: Database["public"]["Enums"]["outbox_state"];
        };
        Relationships: [];
      };
      store_products: {
        Row: {
          active: boolean;
          created_at: string;
          effective_from: string;
          effective_until: string | null;
          environment: string;
          feature_key: string;
          id: string;
          platform: Database["public"]["Enums"]["store_platform"];
          store_product_id: string;
          updated_at: string;
        };
        Insert: {
          active?: boolean;
          created_at?: string;
          effective_from?: string;
          effective_until?: string | null;
          environment: string;
          feature_key: string;
          id?: string;
          platform: Database["public"]["Enums"]["store_platform"];
          store_product_id: string;
          updated_at?: string;
        };
        Update: {
          active?: boolean;
          created_at?: string;
          effective_from?: string;
          effective_until?: string | null;
          environment?: string;
          feature_key?: string;
          id?: string;
          platform?: Database["public"]["Enums"]["store_platform"];
          store_product_id?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      store_transactions: {
        Row: {
          created_at: string;
          effective_until: string | null;
          environment: string;
          id: string;
          original_transaction_id: string;
          platform: Database["public"]["Enums"]["store_platform"];
          product_id: string;
          purchased_at: string;
          purchaser_id: string;
          signed_data_hash: string;
          state: Database["public"]["Enums"]["store_transaction_state"];
          transaction_id: string;
        };
        Insert: {
          created_at?: string;
          effective_until?: string | null;
          environment: string;
          id?: string;
          original_transaction_id: string;
          platform: Database["public"]["Enums"]["store_platform"];
          product_id: string;
          purchased_at: string;
          purchaser_id: string;
          signed_data_hash: string;
          state: Database["public"]["Enums"]["store_transaction_state"];
          transaction_id: string;
        };
        Update: {
          created_at?: string;
          effective_until?: string | null;
          environment?: string;
          id?: string;
          original_transaction_id?: string;
          platform?: Database["public"]["Enums"]["store_platform"];
          product_id?: string;
          purchased_at?: string;
          purchaser_id?: string;
          signed_data_hash?: string;
          state?: Database["public"]["Enums"]["store_transaction_state"];
          transaction_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "store_transactions_product_id_fkey";
            columns: ["product_id"];
            isOneToOne: false;
            referencedRelation: "store_products";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "store_transactions_purchaser_id_fkey";
            columns: ["purchaser_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      students: {
        Row: {
          created_at: string;
          created_by: string;
          deleted_at: string | null;
          display_name: string;
          id: string;
          provisional: boolean;
          school_id: string;
          studafy_id: string;
          updated_at: string;
          user_id: string | null;
        };
        Insert: {
          created_at?: string;
          created_by: string;
          deleted_at?: string | null;
          display_name: string;
          id?: string;
          provisional?: boolean;
          school_id: string;
          studafy_id: string;
          updated_at?: string;
          user_id?: string | null;
        };
        Update: {
          created_at?: string;
          created_by?: string;
          deleted_at?: string | null;
          display_name?: string;
          id?: string;
          provisional?: boolean;
          school_id?: string;
          studafy_id?: string;
          updated_at?: string;
          user_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "students_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "students_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "students_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      submission_attempts: {
        Row: {
          answer_text: string | null;
          created_at: string;
          id: string;
          operation_id: string;
          school_id: string;
          submission_id: string;
          submitted_at: string;
        };
        Insert: {
          answer_text?: string | null;
          created_at?: string;
          id?: string;
          operation_id: string;
          school_id: string;
          submission_id: string;
          submitted_at: string;
        };
        Update: {
          answer_text?: string | null;
          created_at?: string;
          id?: string;
          operation_id?: string;
          school_id?: string;
          submission_id?: string;
          submitted_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "db020_submission_attempts_submission_school_fk";
            columns: ["school_id", "submission_id"];
            isOneToOne: false;
            referencedRelation: "submissions";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "submission_attempts_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "submission_attempts_submission_id_fkey";
            columns: ["submission_id"];
            isOneToOne: false;
            referencedRelation: "submissions";
            referencedColumns: ["id"];
          },
        ];
      };
      submissions: {
        Row: {
          assignment_id: string;
          created_at: string;
          current_attempt_id: string | null;
          excused: boolean;
          id: string;
          school_id: string;
          status: Database["public"]["Enums"]["submission_status"];
          student_id: string;
          submitted_at: string | null;
          updated_at: string;
          version: number;
        };
        Insert: {
          assignment_id: string;
          created_at?: string;
          current_attempt_id?: string | null;
          excused?: boolean;
          id?: string;
          school_id: string;
          status: Database["public"]["Enums"]["submission_status"];
          student_id: string;
          submitted_at?: string | null;
          updated_at?: string;
          version?: number;
        };
        Update: {
          assignment_id?: string;
          created_at?: string;
          current_attempt_id?: string | null;
          excused?: boolean;
          id?: string;
          school_id?: string;
          status?: Database["public"]["Enums"]["submission_status"];
          student_id?: string;
          submitted_at?: string | null;
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "db020_submissions_assignment_school_fk";
            columns: ["school_id", "assignment_id"];
            isOneToOne: false;
            referencedRelation: "assignments";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_submissions_current_attempt_school_fk";
            columns: ["school_id", "id", "current_attempt_id"];
            isOneToOne: false;
            referencedRelation: "submission_attempts";
            referencedColumns: ["school_id", "submission_id", "id"];
          },
          {
            foreignKeyName: "db020_submissions_student_school_fk";
            columns: ["school_id", "student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "submissions_assignment_id_fkey";
            columns: ["assignment_id"];
            isOneToOne: false;
            referencedRelation: "assignments";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "submissions_current_attempt_id_fkey";
            columns: ["current_attempt_id"];
            isOneToOne: false;
            referencedRelation: "submission_attempts";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "submissions_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
      subscription_entitlements: {
        Row: {
          active: boolean;
          expires_at: string | null;
          product_id: string;
          source: string;
          updated_at: string;
          user_id: string;
          verified_at: string;
        };
        Insert: {
          active?: boolean;
          expires_at?: string | null;
          product_id: string;
          source: string;
          updated_at?: string;
          user_id: string;
          verified_at?: string;
        };
        Update: {
          active?: boolean;
          expires_at?: string | null;
          product_id?: string;
          source?: string;
          updated_at?: string;
          user_id?: string;
          verified_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "subscription_entitlements_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: true;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      support_access_grants: {
        Row: {
          approved_by: string | null;
          created_at: string;
          ended_at: string | null;
          expires_at: string;
          id: string;
          mfa_verified_at: string;
          reason: string;
          requested_by: string;
          requires_second_approver: boolean;
          resource_scope: Json;
          revoked_by: string | null;
          revoked_reason: string | null;
          school_id: string;
          started_at: string | null;
          status: Database["public"]["Enums"]["support_access_status"];
          ticket_ref: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          approved_by?: string | null;
          created_at?: string;
          ended_at?: string | null;
          expires_at: string;
          id?: string;
          mfa_verified_at: string;
          reason: string;
          requested_by: string;
          requires_second_approver?: boolean;
          resource_scope?: Json;
          revoked_by?: string | null;
          revoked_reason?: string | null;
          school_id: string;
          started_at?: string | null;
          status?: Database["public"]["Enums"]["support_access_status"];
          ticket_ref: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          approved_by?: string | null;
          created_at?: string;
          ended_at?: string | null;
          expires_at?: string;
          id?: string;
          mfa_verified_at?: string;
          reason?: string;
          requested_by?: string;
          requires_second_approver?: boolean;
          resource_scope?: Json;
          revoked_by?: string | null;
          revoked_reason?: string | null;
          school_id?: string;
          started_at?: string | null;
          status?: Database["public"]["Enums"]["support_access_status"];
          ticket_ref?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "support_access_grants_approved_by_fkey";
            columns: ["approved_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "support_access_grants_requested_by_fkey";
            columns: ["requested_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "support_access_grants_revoked_by_fkey";
            columns: ["revoked_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "support_access_grants_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      terms: {
        Row: {
          active: boolean;
          ends_on: string;
          id: string;
          name: string;
          school_id: string;
          starts_on: string;
          status: Database["public"]["Enums"]["term_status"];
          updated_at: string;
        };
        Insert: {
          active?: boolean;
          ends_on: string;
          id?: string;
          name: string;
          school_id: string;
          starts_on: string;
          status: Database["public"]["Enums"]["term_status"];
          updated_at?: string;
        };
        Update: {
          active?: boolean;
          ends_on?: string;
          id?: string;
          name?: string;
          school_id?: string;
          starts_on?: string;
          status?: Database["public"]["Enums"]["term_status"];
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "terms_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      upload_sessions: {
        Row: {
          actual_size_bytes: number | null;
          allowed_media_types: string[];
          assignment_id: string | null;
          bucket: string | null;
          classroom_id: string | null;
          completed_at: string | null;
          created_at: string;
          declared_media_type: string | null;
          display_name: string | null;
          expected_sha256: string | null;
          expected_size_bytes: number;
          expires_at: string;
          failure_code: string | null;
          file_object_id: string | null;
          grade_result_id: string | null;
          id: string;
          nonce_hash: string;
          object_key: string | null;
          owner_id: string | null;
          owner_membership_id: string | null;
          policy_version: string;
          purpose: string;
          school_id: string;
          state: Database["public"]["Enums"]["upload_session_state"];
          student_id: string | null;
          updated_at: string;
          uploader_id: string;
        };
        Insert: {
          actual_size_bytes?: number | null;
          allowed_media_types: string[];
          assignment_id?: string | null;
          bucket?: string | null;
          classroom_id?: string | null;
          completed_at?: string | null;
          created_at?: string;
          declared_media_type?: string | null;
          display_name?: string | null;
          expected_sha256?: string | null;
          expected_size_bytes: number;
          expires_at: string;
          failure_code?: string | null;
          file_object_id?: string | null;
          grade_result_id?: string | null;
          id?: string;
          nonce_hash: string;
          object_key?: string | null;
          owner_id?: string | null;
          owner_membership_id?: string | null;
          policy_version?: string;
          purpose: string;
          school_id: string;
          state?: Database["public"]["Enums"]["upload_session_state"];
          student_id?: string | null;
          updated_at?: string;
          uploader_id: string;
        };
        Update: {
          actual_size_bytes?: number | null;
          allowed_media_types?: string[];
          assignment_id?: string | null;
          bucket?: string | null;
          classroom_id?: string | null;
          completed_at?: string | null;
          created_at?: string;
          declared_media_type?: string | null;
          display_name?: string | null;
          expected_sha256?: string | null;
          expected_size_bytes?: number;
          expires_at?: string;
          failure_code?: string | null;
          file_object_id?: string | null;
          grade_result_id?: string | null;
          id?: string;
          nonce_hash?: string;
          object_key?: string | null;
          owner_id?: string | null;
          owner_membership_id?: string | null;
          policy_version?: string;
          purpose?: string;
          school_id?: string;
          state?: Database["public"]["Enums"]["upload_session_state"];
          student_id?: string | null;
          updated_at?: string;
          uploader_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "db020_upload_sessions_file_school_fk";
            columns: ["school_id", "file_object_id"];
            isOneToOne: false;
            referencedRelation: "file_objects";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "file050_upload_assignment_school_fk";
            columns: ["school_id", "assignment_id"];
            isOneToOne: false;
            referencedRelation: "assignments";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "file050_upload_classroom_school_fk";
            columns: ["school_id", "classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "file050_upload_grade_school_fk";
            columns: ["school_id", "grade_result_id"];
            isOneToOne: false;
            referencedRelation: "grade_results";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "file050_upload_owner_school_fk";
            columns: ["school_id", "owner_membership_id", "owner_id"];
            isOneToOne: false;
            referencedRelation: "memberships";
            referencedColumns: ["school_id", "id", "user_id"];
          },
          {
            foreignKeyName: "file050_upload_student_school_fk";
            columns: ["school_id", "student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "upload_sessions_file_object_id_fkey";
            columns: ["file_object_id"];
            isOneToOne: false;
            referencedRelation: "file_objects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "upload_sessions_owner_id_fkey";
            columns: ["owner_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "upload_sessions_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "upload_sessions_uploader_id_fkey";
            columns: ["uploader_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      user_blocks: {
        Row: {
          blocked_id: string;
          blocker_id: string;
          created_at: string;
          expires_at: string | null;
          id: string;
          reason: string | null;
          school_id: string;
          scope: string;
          updated_at: string;
          version: number;
        };
        Insert: {
          blocked_id: string;
          blocker_id: string;
          created_at?: string;
          expires_at?: string | null;
          id?: string;
          reason?: string | null;
          school_id: string;
          scope?: string;
          updated_at?: string;
          version?: number;
        };
        Update: {
          blocked_id?: string;
          blocker_id?: string;
          created_at?: string;
          expires_at?: string | null;
          id?: string;
          reason?: string | null;
          school_id?: string;
          scope?: string;
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "user_blocks_blocked_id_fkey";
            columns: ["blocked_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "user_blocks_blocker_id_fkey";
            columns: ["blocker_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "user_blocks_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      wellbeing_events: {
        Row: {
          classroom_id: string | null;
          context: string | null;
          created_at: string;
          created_by: string;
          follow_up: string | null;
          id: string;
          kind: string;
          school_id: string;
          severity: string;
          status: string;
          student_id: string;
          title: string;
          updated_at: string;
          visibility: Database["public"]["Enums"]["wellbeing_visibility"];
        };
        Insert: {
          classroom_id?: string | null;
          context?: string | null;
          created_at?: string;
          created_by: string;
          follow_up?: string | null;
          id?: string;
          kind: string;
          school_id: string;
          severity?: string;
          status?: string;
          student_id: string;
          title: string;
          updated_at?: string;
          visibility?: Database["public"]["Enums"]["wellbeing_visibility"];
        };
        Update: {
          classroom_id?: string | null;
          context?: string | null;
          created_at?: string;
          created_by?: string;
          follow_up?: string | null;
          id?: string;
          kind?: string;
          school_id?: string;
          severity?: string;
          status?: string;
          student_id?: string;
          title?: string;
          updated_at?: string;
          visibility?: Database["public"]["Enums"]["wellbeing_visibility"];
        };
        Relationships: [
          {
            foreignKeyName: "db020_wellbeing_events_classroom_school_fk";
            columns: ["school_id", "classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "db020_wellbeing_events_student_school_fk";
            columns: ["school_id", "student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["school_id", "id"];
          },
          {
            foreignKeyName: "wellbeing_events_classroom_id_fkey";
            columns: ["classroom_id"];
            isOneToOne: false;
            referencedRelation: "classrooms";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "wellbeing_events_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "wellbeing_events_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      mark_notifications_read: { Args: never; Returns: number };
      record_policy_consent: {
        Args: {
          requested_locale?: string;
          requested_purpose: string;
          requested_version: string;
        };
        Returns: undefined;
      };
    };
    Enums: {
      app_role: "school_admin" | "teacher" | "parent" | "guardian" | "student";
      attendance_state: "present" | "absent" | "late" | "excused";
      classroom_staff_role: "lead_teacher" | "co_teacher" | "assistant";
      classroom_status: "draft" | "active" | "archived";
      conversation_state: "active" | "archived" | "closed";
      delivery_state: "pending" | "sent" | "retry" | "failed" | "cancelled";
      enrollment_status: "invited" | "active" | "withdrawn" | "completed";
      entitlement_status:
        | "pending"
        | "active"
        | "grace_period"
        | "on_hold"
        | "revoked"
        | "expired";
      file_purpose:
        | "profile_image"
        | "lesson_resource"
        | "assignment_material"
        | "assignment_submission"
        | "paper_scan"
        | "coach_attachment";
      file_scan_state:
        | "quarantined"
        | "scanning"
        | "clean"
        | "rejected"
        | "error"
        | "deleted";
      invitation_status: "pending" | "accepted" | "revoked" | "expired";
      lesson_session_status: "scheduled" | "completed" | "cancelled";
      link_status: "pending" | "verified" | "declined" | "revoked";
      meeting_audience: "students" | "guardians" | "both";
      membership_status:
        | "invited"
        | "active"
        | "suspended"
        | "revoked"
        | "expired";
      moderation_access_status:
        | "pending"
        | "approved"
        | "active"
        | "expired"
        | "revoked"
        | "denied";
      outbox_state:
        | "pending"
        | "processing"
        | "retry"
        | "completed"
        | "dead_letter"
        | "cancelled";
      profile_status: "active" | "suspended" | "deletion_pending" | "deleted";
      publication_state: "draft" | "reviewed" | "published" | "withdrawn";
      report_event_kind:
        | "submitted"
        | "queued"
        | "triage"
        | "assign"
        | "resolve"
        | "escalate"
        | "hold"
        | "release_hold"
        | "appeal"
        | "withdraw"
        | "evidence_added"
        | "reporter_alerted";
      report_kind: "message" | "conversation" | "user";
      report_resolution: "upheld" | "not_upheld" | "partial" | "no_action";
      report_status:
        | "submitted"
        | "queued"
        | "under_review"
        | "on_hold"
        | "escalated"
        | "resolved"
        | "withdrawn";
      resource_state: "draft" | "published" | "withdrawn" | "archived";
      school_status: "provisioning" | "active" | "suspended" | "closed";
      staff_assignment_status: "active" | "ended";
      store_platform: "app_store" | "play_store" | "school";
      store_transaction_state:
        | "pending"
        | "active"
        | "grace_period"
        | "on_hold"
        | "refunded"
        | "revoked"
        | "expired";
      submission_status: "open" | "submitted" | "excused" | "withdrawn";
      support_access_status:
        | "pending"
        | "approved"
        | "active"
        | "expired"
        | "revoked"
        | "denied";
      term_status: "planned" | "active" | "closed" | "cancelled";
      upload_session_state:
        | "initiated"
        | "uploaded"
        | "completed"
        | "expired"
        | "cancelled"
        | "rejected";
      wellbeing_visibility:
        | "class_staff"
        | "guardian_shared"
        | "student_guardian_shared"
        | "safeguarding_restricted";
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">;

type DefaultSchema =
  DatabaseWithoutInternals[Extract<keyof Database, "public">];

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof (
      & DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
        "Tables"
      ]
      & DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
        "Views"
      ]
    )
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
} ? (
    & DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
      "Tables"
    ]
    & DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
      "Views"
    ]
  )[TableName] extends {
    Row: infer R;
  } ? R
  : never
  : DefaultSchemaTableNameOrOptions extends keyof (
    & DefaultSchema["Tables"]
    & DefaultSchema["Views"]
  ) ? (
      & DefaultSchema["Tables"]
      & DefaultSchema["Views"]
    )[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R;
    } ? R
    : never
  : never;

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
      "Tables"
    ]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
} ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
    "Tables"
  ][TableName] extends {
    Insert: infer I;
  } ? I
  : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I;
    } ? I
    : never
  : never;

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
      "Tables"
    ]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
} ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
    "Tables"
  ][TableName] extends {
    Update: infer U;
  } ? U
  : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U;
    } ? U
    : never
  : never;

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]][
      "Enums"
    ]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
} ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][
    EnumName
  ]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never;

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof DatabaseWithoutInternals[
      PublicCompositeTypeNameOrOptions["schema"]
    ]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
} ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]][
    "CompositeTypes"
  ][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends
    keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never;

export const Constants = {
  public: {
    Enums: {
      app_role: ["school_admin", "teacher", "parent", "guardian", "student"],
      attendance_state: ["present", "absent", "late", "excused"],
      classroom_staff_role: ["lead_teacher", "co_teacher", "assistant"],
      classroom_status: ["draft", "active", "archived"],
      conversation_state: ["active", "archived", "closed"],
      delivery_state: ["pending", "sent", "retry", "failed", "cancelled"],
      enrollment_status: ["invited", "active", "withdrawn", "completed"],
      entitlement_status: [
        "pending",
        "active",
        "grace_period",
        "on_hold",
        "revoked",
        "expired",
      ],
      file_purpose: [
        "profile_image",
        "lesson_resource",
        "assignment_material",
        "assignment_submission",
        "paper_scan",
        "coach_attachment",
      ],
      file_scan_state: [
        "quarantined",
        "scanning",
        "clean",
        "rejected",
        "error",
        "deleted",
      ],
      invitation_status: ["pending", "accepted", "revoked", "expired"],
      lesson_session_status: ["scheduled", "completed", "cancelled"],
      link_status: ["pending", "verified", "declined", "revoked"],
      meeting_audience: ["students", "guardians", "both"],
      membership_status: [
        "invited",
        "active",
        "suspended",
        "revoked",
        "expired",
      ],
      moderation_access_status: [
        "pending",
        "approved",
        "active",
        "expired",
        "revoked",
        "denied",
      ],
      outbox_state: [
        "pending",
        "processing",
        "retry",
        "completed",
        "dead_letter",
        "cancelled",
      ],
      profile_status: ["active", "suspended", "deletion_pending", "deleted"],
      publication_state: ["draft", "reviewed", "published", "withdrawn"],
      report_event_kind: [
        "submitted",
        "queued",
        "triage",
        "assign",
        "resolve",
        "escalate",
        "hold",
        "release_hold",
        "appeal",
        "withdraw",
        "evidence_added",
        "reporter_alerted",
      ],
      report_kind: ["message", "conversation", "user"],
      report_resolution: ["upheld", "not_upheld", "partial", "no_action"],
      report_status: [
        "submitted",
        "queued",
        "under_review",
        "on_hold",
        "escalated",
        "resolved",
        "withdrawn",
      ],
      resource_state: ["draft", "published", "withdrawn", "archived"],
      school_status: ["provisioning", "active", "suspended", "closed"],
      staff_assignment_status: ["active", "ended"],
      store_platform: ["app_store", "play_store", "school"],
      store_transaction_state: [
        "pending",
        "active",
        "grace_period",
        "on_hold",
        "refunded",
        "revoked",
        "expired",
      ],
      submission_status: ["open", "submitted", "excused", "withdrawn"],
      support_access_status: [
        "pending",
        "approved",
        "active",
        "expired",
        "revoked",
        "denied",
      ],
      term_status: ["planned", "active", "closed", "cancelled"],
      upload_session_state: [
        "initiated",
        "uploaded",
        "completed",
        "expired",
        "cancelled",
        "rejected",
      ],
      wellbeing_visibility: [
        "class_staff",
        "guardian_shared",
        "student_guardian_shared",
        "safeguarding_restricted",
      ],
    },
  },
} as const;
